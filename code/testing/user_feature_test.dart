import 'package:flutter_test/flutter_test.dart';

import '../architecture/user_feature.dart';
import '../dart/result.dart';

/// A fake, not a mock: a real implementation with a simple in-memory backing.
///
/// Fakes read better than mock setups, do not drift when the interface changes
/// in a way a mock would happily ignore, and can assert on call counts when
/// that matters.
class FakeUserApi implements UserApi {
  FakeUserApi({this.users = const <String, Map<String, Object?>>{}});

  final Map<String, Map<String, Object?>> users;
  final List<String> calls = <String>[];
  Object? nextError;

  @override
  Future<Map<String, Object?>> fetchUser(String id) async {
    calls.add('fetchUser($id)');
    final Object? error = nextError;
    if (error != null) {
      nextError = null;
      throw error;
    }
    final Map<String, Object?>? user = users[id];
    if (user == null) {
      throw StateError('404');
    }
    return user;
  }

  @override
  Future<List<Map<String, Object?>>> searchUsers(String query) async {
    calls.add('searchUsers($query)');
    return users.values
        .where(
          (Map<String, Object?> user) =>
              (user['full_name']! as String).toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Future<Map<String, Object?>> patchUser(
    String id,
    Map<String, Object?> body,
  ) async {
    calls.add('patchUser($id)');
    final Map<String, Object?> updated = <String, Object?>{
      ...users[id]!,
      ...body,
    };
    users[id] = updated;
    return updated;
  }
}

Map<String, Object?> jsonUser({
  String id = 'u1',
  String? name = 'Ada Lovelace',
  String? email = 'ada@example.com',
  String? avatar,
}) =>
    <String, Object?>{
      'id': id,
      'full_name': name,
      'email': email,
      'avatar_url': avatar,
    };

void main() {
  group('UserDto', () {
    test('maps a complete payload to an entity', () {
      final User user = UserDto.fromJson(jsonUser()).toEntity();

      expect(user.id, 'u1');
      expect(user.name, 'Ada Lovelace');
      expect(user.initials, 'AL');
      expect(user.hasAvatar, isFalse);
    });

    test('fails at the boundary when a required field is missing', () {
      expect(
        () => UserDto.fromJson(jsonUser(email: null)).toEntity(),
        throwsA(isA<FormatException>()),
        reason: 'the parse must fail here, not three screens away',
      );
    });
  });

  group('UserRepositoryImpl', () {
    test('answers from the cache without hitting the network', () async {
      final FakeUserApi api = FakeUserApi(
        users: <String, Map<String, Object?>>{'u1': jsonUser()},
      );
      final UserRepository repository = UserRepositoryImpl(
        api: api,
        cache: InMemoryUserCache(),
      );

      await repository.byId('u1');
      await repository.byId('u1');

      expect(api.calls, <String>['fetchUser(u1)']);
    });

    test('turns a thrown error into a Failure', () async {
      final FakeUserApi api = FakeUserApi()..nextError = StateError('offline');
      final UserRepository repository = UserRepositoryImpl(
        api: api,
        cache: InMemoryUserCache(),
      );

      final Result<User> result = await repository.byId('u1');

      expect(result, isA<Failure<User>>());
      expect(
        result.fold(
          onSuccess: (User _) => 'success',
          onFailure: (Object error, StackTrace _) => error.toString(),
        ),
        contains('offline'),
      );
    });

    test('a malformed payload is a Failure, not a crash', () async {
      final FakeUserApi api = FakeUserApi(
        users: <String, Map<String, Object?>>{'u1': jsonUser(name: null)},
      );
      final UserRepository repository = UserRepositoryImpl(
        api: api,
        cache: InMemoryUserCache(),
      );

      expect(await repository.byId('u1'), isA<Failure<User>>());
    });
  });

  group('RenameUser', () {
    late FakeUserApi api;
    late RenameUser renameUser;

    setUp(() {
      api = FakeUserApi(
        users: <String, Map<String, Object?>>{'u1': jsonUser()},
      );
      renameUser = RenameUser(
        UserRepositoryImpl(api: api, cache: InMemoryUserCache()),
      );
    });

    test('rejects a name that is too short before calling the API', () async {
      final Result<User> result = await renameUser('u1', ' A ');

      expect(result, isA<Failure<User>>());
      expect(api.calls, isEmpty, reason: 'validation runs before the network');
    });

    test('trims and forwards a valid name', () async {
      final Result<User> result = await renameUser('u1', '  Grace Hopper  ');

      expect(
        result.fold(
          onSuccess: (User user) => user.name,
          onFailure: (Object error, StackTrace _) => 'failed: $error',
        ),
        'Grace Hopper',
      );
      expect(api.calls, contains('patchUser(u1)'));
    });
  });
}
