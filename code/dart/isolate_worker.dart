/// Two ways to get work off the UI isolate, and when each one is right.
///
/// `Isolate.run` for one-off work: it spawns, runs, returns and shuts down.
/// [IsolateWorker] for repeated work: spawning costs a few milliseconds and
/// megabytes, so paying it per item in a loop is worse than not using an
/// isolate at all.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

/// Parses and reduces a large JSON payload off the calling isolate.
///
/// The threshold worth knowing: anything under about a millisecond is cheaper
/// to run inline than to hand off, because the arguments and the result are
/// copied between isolates. Measure before assuming a parse is heavy.
Future<List<String>> parseNamesOffThread(String payload) {
  // The closure runs on a fresh isolate. It may only capture values that can
  // cross an isolate boundary — `payload` here is a String, which is fine. A
  // captured `BuildContext`, plugin instance or open database handle is not.
  return Isolate.run<List<String>>(() {
    final Object? decoded = jsonDecode(payload);
    if (decoded is! List<Object?>) {
      throw const FormatException('expected a JSON array');
    }
    return decoded
        .whereType<Map<String, Object?>>()
        .map((Map<String, Object?> item) => item['name'])
        .whereType<String>()
        .toList(growable: false);
  });
}

/// A long-lived isolate that answers requests over a port.
///
/// Use this when the same expensive operation runs repeatedly — decoding
/// frames, running a parser over every synced record, applying a CPU-bound
/// transform per user action. One spawn, many jobs.
class IsolateWorker {
  IsolateWorker._(this._isolate, this._toWorker, this._fromWorker);

  final Isolate _isolate;
  final SendPort _toWorker;
  final ReceivePort _fromWorker;

  final Map<int, Completer<Object?>> _pending = <int, Completer<Object?>>{};
  int _nextId = 0;
  bool _closed = false;

  /// Spawns the worker and completes once it has reported its receive port.
  static Future<IsolateWorker> spawn() async {
    final ReceivePort fromWorker = ReceivePort();
    final Completer<SendPort> handshake = Completer<SendPort>();
    IsolateWorker? worker;

    // The first message from the worker is always its own SendPort. Until it
    // arrives there is no way to send anything, which is why spawn() is async.
    fromWorker.listen((Object? message) {
      if (message is SendPort && !handshake.isCompleted) {
        handshake.complete(message);
        return;
      }
      // Replies can only arrive after a job was sent, and only the returned
      // instance can send one — so `worker` is always assigned by then.
      worker?._handleResponse(message);
    });

    final Isolate isolate = await Isolate.spawn<SendPort>(
      _workerEntryPoint,
      fromWorker.sendPort,
      errorsAreFatal: true,
      debugName: 'IsolateWorker',
    );

    final SendPort toWorker = await handshake.future;
    worker = IsolateWorker._(isolate, toWorker, fromWorker);
    return worker;
  }

  /// Sends [message] to the worker and completes with its reply.
  ///
  /// Both the message and the reply are deep-copied across the boundary, so
  /// sending a 20 MB list twice per second costs more than the work saved.
  Future<Object?> send(Object? message) {
    if (_closed) {
      throw StateError('IsolateWorker has been closed');
    }
    final int id = _nextId++;
    final Completer<Object?> completer = Completer<Object?>();
    _pending[id] = completer;
    _toWorker.send(<Object?>[id, message]);
    return completer.future;
  }

  void _handleResponse(Object? response) {
    if (response is! List<Object?> || response.length != 3) {
      return;
    }
    final int id = response[0]! as int;
    final Completer<Object?>? completer = _pending.remove(id);
    if (completer == null) {
      return;
    }
    final Object? error = response[2];
    if (error != null) {
      completer.completeError(error);
    } else {
      completer.complete(response[1]);
    }
  }

  /// Kills the isolate and fails every request still in flight.
  ///
  /// Forgetting this is a leak with a heartbeat: the isolate stays alive, holds
  /// its heap, and keeps the process from exiting.
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    for (final Completer<Object?> completer in _pending.values) {
      completer.completeError(StateError('IsolateWorker closed'));
    }
    _pending.clear();
    _fromWorker.close();
    _isolate.kill(priority: Isolate.immediate);
  }
}

/// Runs on the spawned isolate. Must be a top-level or static function —
/// closures capture state that cannot cross the boundary.
void _workerEntryPoint(SendPort toMain) {
  final ReceivePort fromMain = ReceivePort();
  toMain.send(fromMain.sendPort);

  fromMain.listen((Object? message) {
    if (message is! List<Object?> || message.length != 2) {
      return;
    }
    final int id = message[0]! as int;
    try {
      toMain.send(<Object?>[id, _handleJob(message[1]), null]);
    } on Object catch (error) {
      // Errors do not propagate across isolates. Catch here and send the
      // message across, or the caller waits forever on a future nobody will
      // complete.
      toMain.send(<Object?>[id, null, error.toString()]);
    }
  });
}

/// The actual work. Swap this for whatever the worker exists to do.
Object? _handleJob(Object? job) {
  if (job is int) {
    return _fibonacci(job);
  }
  if (job is String) {
    return jsonDecode(job);
  }
  throw ArgumentError.value(job, 'job', 'unsupported job type');
}

int _fibonacci(int n) => n < 2 ? n : _fibonacci(n - 1) + _fibonacci(n - 2);
