/// The presentation layer for the user feature, in Riverpod.
///
/// Written against flutter_riverpod 3.4. The point of interest is not the
/// syntax — it is that every dependency is a provider, so a test overrides the
/// repository and the notifier under test never knows the difference.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dart/result.dart';
import 'user_feature.dart';

/// The seam. Overriding this in `main()`, in a flavour, or in a test replaces
/// the entire data layer without touching a widget.
///
/// Throwing by default is deliberate: a forgotten override fails loudly at
/// startup instead of silently using a stub in production.
final Provider<UserRepository> userRepositoryProvider =
    Provider<UserRepository>((Ref ref) {
  throw UnimplementedError(
    'Override userRepositoryProvider in main() or in a test',
  );
});

/// Which user the screen is showing. Kept as its own provider so the notifier
/// below can watch it rather than being told to reload.
final Provider<String> currentUserIdProvider = Provider<String>((Ref ref) {
  throw UnimplementedError('Override currentUserIdProvider per route');
});

final AsyncNotifierProvider<UserNotifier, User> userProvider =
    AsyncNotifierProvider<UserNotifier, User>(UserNotifier.new);

class UserNotifier extends AsyncNotifier<User> {
  @override
  Future<User> build() async {
    // ref.watch inside build creates the dependency graph: change the id and
    // this notifier re-runs, with loading and error states handled for you.
    // That handling is most of what a hand-rolled ChangeNotifier spends its
    // lines on.
    final UserRepository repository = ref.watch(userRepositoryProvider);
    final String id = ref.watch(currentUserIdProvider);

    final Result<User> result = await repository.byId(id);
    return result.fold(
      onSuccess: (User user) => user,
      onFailure: Error.throwWithStackTrace,
    );
  }

  /// Optimistic rename: show the new name immediately, roll back on failure.
  ///
  /// The same shape as an offline mutation — the UI moves first and the
  /// server confirms or reverts it later.
  Future<void> rename(String name) async {
    final User? previous = state.value;
    if (previous != null) {
      state = AsyncData<User>(previous.copyWith(name: name));
    }

    final RenameUser renameUser = RenameUser(ref.read(userRepositoryProvider));
    final Result<User> result = await renameUser(
      ref.read(currentUserIdProvider),
      name,
    );

    state = result.fold(
      onSuccess: AsyncData<User>.new,
      onFailure: (Object error, StackTrace stackTrace) {
        // Roll the optimistic edit back before surfacing the failure, or the
        // screen keeps showing a name the server rejected.
        if (previous != null) {
          state = AsyncData<User>(previous);
        }
        return AsyncError<User>(error, stackTrace);
      },
    );
  }

  /// Throws the cached value away and runs [build] again.
  void refresh() => ref.invalidateSelf();
}

/// A derived provider. A widget watching this rebuilds only when the initials
/// change — not when the email does.
final Provider<String> userInitialsProvider = Provider<String>((Ref ref) {
  final AsyncValue<User> user = ref.watch(userProvider);
  return user.maybeWhen(
    data: (User user) => user.initials,
    orElse: () => '',
  );
});
