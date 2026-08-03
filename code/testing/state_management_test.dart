import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../architecture/bloc_search.dart';
import '../architecture/riverpod_user.dart';
import '../architecture/user_feature.dart';
import '../dart/result.dart';

/// A repository fake that answers from a map and can be told to fail.
class FakeUserRepository implements UserRepository {
  FakeUserRepository(this.users);

  final Map<String, User> users;
  Object? nextError;
  int searchCalls = 0;

  Result<T> _fail<T>(Object error) => Failure<T>(error, StackTrace.current);

  @override
  Future<Result<User>> byId(String id) async {
    final Object? error = nextError;
    if (error != null) {
      nextError = null;
      return _fail<User>(error);
    }
    final User? user = users[id];
    return user == null
        ? _fail<User>(StateError('no user $id'))
        : Success<User>(user);
  }

  @override
  Future<Result<List<User>>> search(String query) async {
    searchCalls++;
    final Object? error = nextError;
    if (error != null) {
      nextError = null;
      return _fail<List<User>>(error);
    }
    return Success<List<User>>(
      users.values
          .where(
            (User user) =>
                user.name.toLowerCase().contains(query.toLowerCase()),
          )
          .toList(),
    );
  }

  @override
  Future<Result<User>> rename(String id, String name) async {
    final Object? error = nextError;
    if (error != null) {
      nextError = null;
      return _fail<User>(error);
    }
    final User updated = users[id]!.copyWith(name: name);
    users[id] = updated;
    return Success<User>(updated);
  }
}

const User _ada = User(
  id: 'u1',
  name: 'Ada Lovelace',
  email: 'ada@example.com',
);

FakeUserRepository _repository() =>
    FakeUserRepository(<String, User>{'u1': _ada});

ProviderContainer _container(FakeUserRepository repository) {
  final ProviderContainer container = ProviderContainer(
    overrides: [
      // The seam in use: no widget, no network, no plugin registry.
      userRepositoryProvider.overrideWithValue(repository),
      currentUserIdProvider.overrideWithValue('u1'),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('Riverpod UserNotifier', () {
    test('loads through the overridden repository', () async {
      final ProviderContainer container = _container(_repository());

      expect(container.read(userProvider), isA<AsyncLoading<User>>());
      expect(await container.read(userProvider.future), _ada);
      expect(container.read(userInitialsProvider), 'AL');
    });

    test('a failing load becomes AsyncError rather than an exception',
        () async {
      final FakeUserRepository repository = _repository()
        ..nextError = StateError('offline');
      final ProviderContainer container = _container(repository);

      await expectLater(
        container.read(userProvider.future),
        throwsStateError,
      );
      expect(container.read(userProvider), isA<AsyncError<User>>());
    });

    test('rename updates optimistically and keeps the server value', () async {
      final ProviderContainer container = _container(_repository());
      await container.read(userProvider.future);

      final Future<void> pending =
          container.read(userProvider.notifier).rename('Grace Hopper');

      // The UI already shows the new name, before the repository answered.
      expect(container.read(userProvider).value?.name, 'Grace Hopper');

      await pending;
      expect(container.read(userProvider).value?.name, 'Grace Hopper');
    });

    test('a failed rename rolls the optimistic edit back', () async {
      final FakeUserRepository repository = _repository();
      final ProviderContainer container = _container(repository);
      await container.read(userProvider.future);

      repository.nextError = StateError('rejected');
      await container.read(userProvider.notifier).rename('Grace Hopper');

      expect(container.read(userProvider), isA<AsyncError<User>>());
    });
  });

  group('UserCubit', () {
    test('emits loading then loaded', () async {
      final UserCubit cubit = UserCubit(_repository());
      addTearDown(cubit.close);

      final Future<void> states = expectLater(
        cubit.stream,
        emitsInOrder(<Matcher>[
          isA<UserLoading>(),
          isA<UserLoaded>(),
        ]),
      );

      await cubit.load('u1');
      await states;
    });

    test('emits a failure state instead of throwing', () async {
      final FakeUserRepository repository = _repository()
        ..nextError = StateError('offline');
      final UserCubit cubit = UserCubit(repository);
      addTearDown(cubit.close);

      await cubit.load('u1');

      expect(cubit.state, isA<UserFailed>());
    });
  });

  group('SearchBloc', () {
    test('debounces a burst into a single search', () async {
      final FakeUserRepository repository = _repository();
      final SearchBloc bloc = SearchBloc(repository);
      addTearDown(bloc.close);

      bloc
        ..add(const SearchQueryChanged('a'))
        ..add(const SearchQueryChanged('ad'))
        ..add(const SearchQueryChanged('ada'));

      await bloc.stream.firstWhere(
        (SearchState state) => state.results.isNotEmpty,
      );

      expect(repository.searchCalls, 1, reason: 'one request per pause');
      expect(bloc.state.query, 'ada');
      expect(bloc.state.results, <User>[_ada]);
    });

    test('clearing resets to the initial state', () async {
      final SearchBloc bloc = SearchBloc(_repository());
      addTearDown(bloc.close);

      bloc.add(const SearchCleared());
      await bloc.stream.first;

      expect(bloc.state.query, '');
      expect(bloc.state.results, isEmpty);
    });
  });
}
