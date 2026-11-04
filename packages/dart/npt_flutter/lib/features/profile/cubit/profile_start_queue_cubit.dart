import 'dart:async';

import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_cache_cubit.dart';

part 'profile_start_queue_state.dart';

/// Starts connections one at a time: started together, some time out.
class ProfileStartQueueCubit extends LoggingCubit<ProfileStartQueueState> {
  final ProfileCacheCubit _cache;

  ProfileStartQueueCubit(this._cache)
    : super(const ProfileStartQueueState(<String>[]));

  /// A cap in case a start never reports how it ended.
  static const Duration _stepTimeout = Duration(seconds: 90);

  String? _current;
  bool _stopCurrent = false;
  bool _draining = false;

  Completer<void> _cleared = Completer<void>();

  bool isWaiting(String uuid) => state.isWaiting(uuid);

  void add(Iterable<String> uuids) {
    final List<String> next = List<String>.of(state.waiting);
    for (final String uuid in uuids) {
      if (uuid == _current) {
        // Asked to start again after a Stop all: keep it running.
        _stopCurrent = false;
        continue;
      }
      if (next.contains(uuid)) continue;
      final ProfileBloc bloc = _cache.getProfileBloc(uuid);
      if (!bloc.isClosed && _canQueue(bloc.state)) next.add(uuid);
    }
    _setWaiting(next);
    if (!_draining) _drain();
  }

  /// If the one starting is among [uuids], it is stopped once started.
  void remove(Iterable<String> uuids) {
    final Set<String> removed = uuids.toSet();
    if (removed.contains(_current)) _stopCurrent = true;
    if (!state.waiting.any(removed.contains)) return;
    _setWaiting(
      state.waiting.where((String uuid) => !removed.contains(uuid)).toList(),
    );
  }

  void clear() {
    _setWaiting(const <String>[]);
    if (!_cleared.isCompleted) _cleared.complete();
    _cleared = Completer<void>();
  }

  /// Stops a start in progress without emitting: nothing listens any more.
  @override
  Future<void> close() {
    if (!_cleared.isCompleted) _cleared.complete();
    return super.close();
  }

  void _setWaiting(List<String> waiting) {
    if (isClosed) return;
    emit(ProfileStartQueueState(List<String>.unmodifiable(waiting)));
  }

  static bool _canQueue(ProfileState state) => switch (state) {
    ProfileInitial() ||
    ProfileLoading() ||
    ProfileLoaded() ||
    ProfileFailedSave() ||
    ProfileFailedStart() => true,
    _ => false,
  };

  Future<void> _drain() async {
    _draining = true;
    try {
      // Once closed the waiting list can't shrink, so the loop has to stop.
      while (!isClosed && state.waiting.isNotEmpty) {
        final String uuid = state.waiting.first;
        _setWaiting(state.waiting.skip(1).toList());
        _current = uuid;
        _stopCurrent = false;
        final ProfileBloc bloc = _cache.getProfileBloc(uuid);
        // A deleted connection's bloc is closed; keep going on a failure.
        if (bloc.isClosed) continue;
        try {
          await _start(bloc);
          if (_stopCurrent && !bloc.isClosed && bloc.state is ProfileStarted) {
            bloc.add(const ProfileStopEvent());
          }
        } catch (_) {}
      }
    } finally {
      _current = null;
      _draining = false;
    }
  }

  Future<void> _start(ProfileBloc bloc) async {
    ProfileState state = bloc.state;
    if (state is ProfileInitial || state is ProfileLoading) {
      // Rows load their profile only once they are shown.
      if (state is ProfileInitial) bloc.add(const ProfileLoadEvent());
      final ProfileState? loaded = await _next(
        bloc,
        (ProfileState s) => s is! ProfileInitial && s is! ProfileLoading,
      );
      if (loaded == null || _stopCurrent || bloc.isClosed) return;
      state = loaded;
    }
    if (state is! ProfileLoaded &&
        state is! ProfileFailedSave &&
        state is! ProfileFailedStart) {
      return;
    }
    bloc.add(const ProfileStartEvent());
    await _next(bloc, (ProfileState s) => s is! ProfileStarting);
  }

  /// Null if the queue was cleared, the bloc closed or it took too long.
  Future<ProfileState?> _next(
    ProfileBloc bloc,
    bool Function(ProfileState state) test,
  ) {
    return Future.any<ProfileState?>(<Future<ProfileState?>>[
      bloc.stream
          .firstWhere(test)
          .then<ProfileState?>((ProfileState s) => s, onError: (_) => null),
      _cleared.future.then((_) => null),
    ]).timeout(_stepTimeout, onTimeout: () => null);
  }
}
