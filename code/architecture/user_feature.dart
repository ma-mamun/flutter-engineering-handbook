/// One feature, all four layers, in a single file so the boundaries are visible.
///
/// In a real project each section below is its own file under
/// `lib/features/user/{domain,data,application}`. Keeping them together here
/// makes the point the layering exists for: the domain in the middle depends on
/// nothing, and everything else depends inward.
library;

import '../dart/result.dart';

// ---------------------------------------------------------------------------
// Domain — entities and contracts. No JSON, no HTTP, no Flutter.
// ---------------------------------------------------------------------------

/// What the rest of the app means by "a user".
///
/// Non-nullable where the app requires a value, whatever the wire says. The
/// mapper below is responsible for making that true, and for failing loudly
/// when the payload cannot support it.
final class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;

  /// Genuinely optional: a user may not have uploaded one.
  final String? avatarUrl;

  /// Domain behaviour belongs on the entity, not in a widget or a service.
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  String get initials => name
      .split(' ')
      .where((String part) => part.isNotEmpty)
      .take(2)
      .map((String part) => part[0].toUpperCase())
      .join();

  User copyWith({String? name, String? email, String? avatarUrl}) => User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
      );

  @override
  bool operator ==(Object other) =>
      other is User &&
      other.id == id &&
      other.name == name &&
      other.email == email &&
      other.avatarUrl == avatarUrl;

  @override
  int get hashCode => Object.hash(id, name, email, avatarUrl);
}

/// The contract the domain states and the data layer satisfies.
///
/// Declared here, implemented there — that inversion is what lets the domain
/// stay ignorant of dio, Drift and everything else that will change.
abstract interface class UserRepository {
  Future<Result<User>> byId(String id);

  Future<Result<List<User>>> search(String query);

  Future<Result<User>> rename(String id, String name);
}

/// A use case: one verb, one dependency graph, one place to put the rule.
///
/// Worth writing when the operation has logic of its own — validation,
/// orchestration across two repositories, a policy. A use case that only
/// forwards to a repository is a file with no content, and repository calls
/// from the presentation layer are fine in that case.
final class RenameUser {
  const RenameUser(this._users);

  final UserRepository _users;

  Future<Result<User>> call(String id, String name) async {
    final String trimmed = name.trim();
    if (trimmed.length < 2) {
      return Failure<User>(
        const ValidationFailure('Name must be at least two characters'),
        StackTrace.current,
      );
    }
    return _users.rename(id, trimmed);
  }
}

/// A domain-level failure, distinct from whatever the network threw.
final class ValidationFailure implements Exception {
  const ValidationFailure(this.message);

  final String message;

  @override
  String toString() => 'ValidationFailure: $message';
}

// ---------------------------------------------------------------------------
// Data — DTOs, mappers, and the implementation of the contract above.
// ---------------------------------------------------------------------------

/// The shape of the wire, not the shape of the app.
///
/// Every field is nullable because the server can omit any of them, whatever
/// the API documentation claims. Lying here moves the crash from the parser —
/// where the payload is in scope and loggable — into a widget three screens
/// away.
final class UserDto {
  const UserDto({this.id, this.fullName, this.email, this.avatar});

  factory UserDto.fromJson(Map<String, Object?> json) => UserDto(
        id: json['id'] as String?,
        fullName: json['full_name'] as String?,
        email: json['email'] as String?,
        avatar: json['avatar_url'] as String?,
      );

  final String? id;
  final String? fullName;
  final String? email;
  final String? avatar;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'full_name': fullName,
        'email': email,
        'avatar_url': avatar,
      };

  /// The mapper is the only place that knows the difference between "the
  /// server is broken" and "this user has no avatar".
  User toEntity() {
    final String? id = this.id;
    final String? name = fullName;
    final String? email = this.email;
    if (id == null || name == null || email == null) {
      throw const FormatException('user payload missing a required field');
    }
    return User(id: id, name: name, email: email, avatarUrl: avatar);
  }
}

/// What the repository talks to. Swapping dio for http, or a REST API for
/// GraphQL, changes this and nothing above it.
abstract interface class UserApi {
  Future<Map<String, Object?>> fetchUser(String id);

  Future<List<Map<String, Object?>>> searchUsers(String query);

  Future<Map<String, Object?>> patchUser(String id, Map<String, Object?> body);
}

/// A local cache the repository can answer from.
abstract interface class UserCache {
  User? read(String id);

  void write(User user);
}

final class UserRepositoryImpl implements UserRepository {
  const UserRepositoryImpl({required UserApi api, required UserCache cache})
      : _api = api,
        _cache = cache;

  final UserApi _api;
  final UserCache _cache;

  @override
  Future<Result<User>> byId(String id) async {
    // Cache first, network second: the repository is where that policy lives,
    // because it is the only layer that can see both sources.
    final User? cached = _cache.read(id);
    if (cached != null) {
      return Success<User>(cached);
    }

    // guard() turns every throw — socket, timeout, parse — into a value the
    // caller's type signature admits.
    final Result<User> result = await Result.guard<User>(() async {
      final Map<String, Object?> json = await _api.fetchUser(id);
      return UserDto.fromJson(json).toEntity();
    });

    return result.map((User user) {
      _cache.write(user);
      return user;
    });
  }

  @override
  Future<Result<List<User>>> search(String query) {
    return Result.guard<List<User>>(() async {
      final List<Map<String, Object?>> json = await _api.searchUsers(query);
      return json
          .map(UserDto.fromJson)
          .map((UserDto dto) => dto.toEntity())
          .toList(growable: false);
    });
  }

  @override
  Future<Result<User>> rename(String id, String name) {
    return Result.guard<User>(() async {
      final Map<String, Object?> json = await _api.patchUser(
        id,
        <String, Object?>{'full_name': name},
      );
      final User user = UserDto.fromJson(json).toEntity();
      _cache.write(user);
      return user;
    });
  }
}

/// An in-memory cache, useful in tests and as the shape a real one takes.
final class InMemoryUserCache implements UserCache {
  final Map<String, User> _users = <String, User>{};

  @override
  User? read(String id) => _users[id];

  @override
  void write(User user) => _users[user.id] = user;
}
