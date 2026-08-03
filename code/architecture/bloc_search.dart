/// The same feature in BLoC, plus the case where BLoC's ceremony pays for
/// itself: event transformers.
///
/// A Cubit cannot express "debounce these calls and cancel the in-flight one".
/// A Bloc can, in one line, because events are a stream before they are
/// handled.
library;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dart/result.dart';
import '../dart/stream_pipeline.dart';
import 'user_feature.dart';

// ---------------------------------------------------------------------------
// Cubit: no events, just methods. Right for most screens.
// ---------------------------------------------------------------------------

sealed class UserState {
  const UserState();
}

final class UserInitial extends UserState {
  const UserInitial();
}

final class UserLoading extends UserState {
  const UserLoading();
}

final class UserLoaded extends UserState {
  const UserLoaded(this.user);

  final User user;

  @override
  bool operator ==(Object other) => other is UserLoaded && other.user == user;

  @override
  int get hashCode => user.hashCode;
}

final class UserFailed extends UserState {
  const UserFailed(this.message);

  final String message;

  @override
  bool operator ==(Object other) =>
      other is UserFailed && other.message == message;

  @override
  int get hashCode => message.hashCode;
}

class UserCubit extends Cubit<UserState> {
  UserCubit(this._repository) : super(const UserInitial());

  final UserRepository _repository;

  Future<void> load(String id) async {
    emit(const UserLoading());
    final Result<User> result = await _repository.byId(id);
    emit(
      result.fold(
        onSuccess: UserLoaded.new,
        onFailure: (Object error, StackTrace _) => UserFailed(error.toString()),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bloc: events, and the transformer that makes them worth the extra file.
// ---------------------------------------------------------------------------

sealed class SearchEvent {
  const SearchEvent();
}

final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;
}

final class SearchCleared extends SearchEvent {
  const SearchCleared();
}

final class SearchState {
  const SearchState({
    this.query = '',
    this.results = const <User>[],
    this.isLoading = false,
    this.error,
  });

  final String query;
  final List<User> results;
  final bool isLoading;
  final String? error;

  SearchState copyWith({
    String? query,
    List<User>? results,
    bool? isLoading,
    String? error,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._repository) : super(const SearchState()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      // This is the argument for Bloc over Cubit. `restartable` cancels the
      // handler still running when a newer event arrives, so a slow response
      // for "fl" can never overwrite the results for "flutter"; the debounce
      // keeps it to one request per pause in typing.
      transformer: (
        Stream<SearchQueryChanged> events,
        EventMapper<SearchQueryChanged> handler,
      ) =>
          restartable<SearchQueryChanged>()(
        // `debounce` is the extension from code/dart/stream_pipeline.dart —
        // the same forty lines explained on the async page.
        events.debounce(const Duration(milliseconds: 300)),
        handler,
      ),
    );
    on<SearchCleared>(
      (SearchCleared event, Emitter<SearchState> emit) =>
          emit(const SearchState()),
    );
  }

  final UserRepository _repository;

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    final String query = event.query.trim();
    if (query.isEmpty) {
      emit(const SearchState());
      return;
    }

    emit(state.copyWith(query: query, isLoading: true));

    final Result<List<User>> result = await _repository.search(query);

    // After an await inside a handler, the bloc may have been closed. Emitting
    // then throws — the Bloc equivalent of setState after dispose.
    if (isClosed) {
      return;
    }

    emit(
      result.fold(
        onSuccess: (List<User> users) =>
            state.copyWith(results: users, isLoading: false),
        onFailure: (Object error, StackTrace _) =>
            state.copyWith(isLoading: false, error: error.toString()),
      ),
    );
  }
}
