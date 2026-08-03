/// Single-flight token refresh.
///
/// The bug this exists to prevent: an app fires five requests at once, all five
/// get a 401, and all five call the refresh endpoint. Four of those refreshes
/// race, and on a backend that rotates refresh tokens, three of them invalidate
/// the token the others are using — the user is silently logged out.
///
/// The fix is that only the first caller refreshes and everyone else waits on
/// that same future.
library;

import 'dart:async';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// Refresh slightly before expiry: a token that expires while in flight
  /// produces a 401 the user pays for in latency.
  bool isExpired(
    DateTime now, {
    Duration leeway = const Duration(seconds: 30),
  }) =>
      !now.add(leeway).isBefore(expiresAt);
}

/// Persists tokens across restarts. Back this with secure storage — see the
/// secure storage page for why SharedPreferences is not an option.
abstract interface class TokenStore {
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

/// Exchanges a refresh token for a new pair.
typedef RefreshCall = Future<AuthTokens> Function(String refreshToken);

/// Thrown when the refresh token itself is rejected. The only correct response
/// is to sign the user out — retrying cannot help.
class RefreshFailure implements Exception {
  const RefreshFailure(this.cause);

  final Object cause;

  @override
  String toString() => 'RefreshFailure: $cause';
}

class TokenRefresher {
  TokenRefresher({
    required TokenStore store,
    required RefreshCall refresh,
    required DateTime Function() clock,
    Future<void> Function()? onSignOut,
  })  : _store = store,
        _refresh = refresh,
        _clock = clock,
        _onSignOut = onSignOut;

  final TokenStore _store;
  final RefreshCall _refresh;
  final DateTime Function() _clock;
  final Future<void> Function()? _onSignOut;

  /// The in-flight refresh, shared by every caller that arrives during it.
  Future<AuthTokens>? _inFlight;

  int refreshCount = 0;

  /// Returns a usable access token, refreshing first if it is about to expire.
  Future<String> accessToken() async {
    final AuthTokens? current = await _store.read();
    if (current == null) {
      throw const RefreshFailure('no tokens stored');
    }
    if (!current.isExpired(_clock())) {
      return current.accessToken;
    }
    final AuthTokens refreshed = await _refreshOnce(current.refreshToken);
    return refreshed.accessToken;
  }

  /// Called by an interceptor when a request comes back 401.
  ///
  /// Pass the token the failed request used. If it no longer matches what is
  /// stored, another caller already refreshed and the request should simply be
  /// retried with the new token rather than triggering a second refresh.
  Future<String> onUnauthorized(String usedToken) async {
    final AuthTokens? current = await _store.read();
    if (current == null) {
      throw const RefreshFailure('no tokens stored');
    }
    if (current.accessToken != usedToken) {
      return current.accessToken;
    }
    final AuthTokens refreshed = await _refreshOnce(current.refreshToken);
    return refreshed.accessToken;
  }

  Future<AuthTokens> _refreshOnce(String refreshToken) {
    // The whole mechanism: the first caller creates the future, everyone else
    // awaits the same one, and the field is cleared once it settles.
    final Future<AuthTokens>? existing = _inFlight;
    if (existing != null) {
      return existing;
    }

    final Future<AuthTokens> attempt = _performRefresh(refreshToken);
    _inFlight = attempt;
    return attempt.whenComplete(() => _inFlight = null);
  }

  Future<AuthTokens> _performRefresh(String refreshToken) async {
    refreshCount++;
    try {
      final AuthTokens tokens = await _refresh(refreshToken);
      await _store.write(tokens);
      return tokens;
    } on Object catch (error) {
      // A rejected refresh token is terminal. Clear everything and sign out, or
      // the app retries forever against a token that will never work again.
      await _store.clear();
      await _onSignOut?.call();
      throw RefreshFailure(error);
    }
  }
}

/// An in-memory store, for tests and as the shape a real one takes.
class InMemoryTokenStore implements TokenStore {
  InMemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
