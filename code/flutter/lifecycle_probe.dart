/// A widget that records every lifecycle callback it receives, in order.
///
/// The ordering claimed on the widget lifecycle page is asserted by a test
/// against this class, so it cannot drift as the framework changes.
library;

import 'dart:async';

import 'package:flutter/material.dart';

class LifecycleProbe extends StatefulWidget {
  const LifecycleProbe({
    required this.log,
    required this.label,
    super.key,
  });

  /// Shared with the test. A real widget would never take a mutable list like
  /// this — it exists so the callbacks can be observed from outside.
  final List<String> log;
  final String label;

  @override
  State<LifecycleProbe> createState() => LifecycleProbeState();
}

class LifecycleProbeState extends State<LifecycleProbe> {
  @override
  void initState() {
    // super.initState() first, always: the base class sets up state the
    // framework relies on before anything else runs.
    super.initState();
    widget.log.add('initState');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Runs after initState on the first build, and again whenever an inherited
    // widget this State depends on changes. This is where `Theme.of`,
    // `MediaQuery.of` and `context.watch` work and `initState` does not.
    widget.log.add('didChangeDependencies');
  }

  @override
  void didUpdateWidget(covariant LifecycleProbe oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The State object survived; only its configuration changed. Anything
    // derived from widget fields — a controller, a subscription, a future —
    // must be rebuilt here, and the old one disposed.
    widget.log.add('didUpdateWidget ${oldWidget.label}->${widget.label}');
  }

  @override
  void deactivate() {
    // The element was removed from the tree. It may be reinserted in the same
    // frame — that is how a GlobalKey move works — so this is not dispose.
    widget.log.add('deactivate');
    super.deactivate();
  }

  @override
  void activate() {
    super.activate();
    widget.log.add('activate');
  }

  @override
  void dispose() {
    // Last call. `mounted` is already false. Release everything here.
    widget.log.add('dispose');
    super.dispose();
  }

  /// Exposed so a test can trigger a rebuild the way a callback would.
  void bump() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Reading an inherited widget here registers a dependency, and that
    // registration is what makes didChangeDependencies fire when the
    // MediaQuery above changes. A State that reads nothing inherited never
    // sees that callback again after the first build.
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    widget.log.add('build');
    return Text(
      widget.label,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    );
  }
}

/// Demonstrates the `mounted` guard after an await.
///
/// Without the check, a screen the user has already left calls setState on a
/// disposed State — the crash reproduces only when the network is slow enough
/// for the user to navigate away first.
class DelayedLoader extends StatefulWidget {
  const DelayedLoader({required this.load, super.key});

  final Future<String> Function() load;

  @override
  State<DelayedLoader> createState() => _DelayedLoaderState();
}

class _DelayedLoaderState extends State<DelayedLoader> {
  String _value = 'loading';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final String result = await widget.load();
    // The gap across this await is where the widget can be disposed. Everything
    // below touches State or context, so everything below needs this guard.
    if (!mounted) {
      return;
    }
    setState(() => _value = result);
  }

  @override
  Widget build(BuildContext context) =>
      Text(_value, textDirection: TextDirection.ltr);
}
