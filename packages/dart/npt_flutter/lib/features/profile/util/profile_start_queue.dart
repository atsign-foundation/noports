import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:npt_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_cache_cubit.dart';

/// Starts connections one after another. Started together, several of them
/// can time out waiting for their device to answer.
class ProfileStartQueue {
  ProfileStartQueue._();

  /// Connections waiting for their turn, in order. The one starting isn't in
  /// it.
  static final ValueNotifier<List<String>> waiting =
      ValueNotifier<List<String>>(const <String>[]);

  /// A cap in case a start never reports how it ended.
  static const Duration _stepTimeout = Duration(seconds: 90);

  static String? _current;
  static bool _stopCurrent = false;
  static bool _draining = false;

  /// Completed by [clear], so a start in progress stops holding the queue.
  static Completer<void> _cleared = Completer<void>();

  static bool isWaiting(String uuid) => waiting.value.contains(uuid);

  /// Queues the connections of [uuids] that aren't already running.
  static void add(ProfileCacheCubit cache, Iterable<String> uuids) {
    final List<String> next = List<String>.of(waiting.value);
    for (final String uuid in uuids) {
      if (uuid == _current) {
        // Asked to start again after a Stop all: keep it running.
        _stopCurrent = false;
        continue;
      }
      if (next.contains(uuid)) continue;
      final ProfileBloc bloc = cache.getProfileBloc(uuid);
      if (!bloc.isClosed && _canQueue(bloc.state)) next.add(uuid);
    }
    waiting.value = List<String>.unmodifiable(next);
    if (!_draining) _drain(cache);
  }

  /// Takes [uuids] out of the queue. If one of them is starting, it is
  /// stopped once started.
  static void remove(Iterable<String> uuids) {
    final Set<String> removed = uuids.toSet();
    if (removed.contains(_current)) _stopCurrent = true;
    if (!waiting.value.any(removed.contains)) return;
    waiting.value = List<String>.unmodifiable(
      waiting.value.where((String uuid) => !removed.contains(uuid)),
    );
  }

  /// On sign out: drops the queue without waiting for the current start,
  /// which carries on like a start from its row would.
  static void clear() {
    waiting.value = const <String>[];
    _cleared.complete();
    _cleared = Completer<void>();
  }

  static bool _canQueue(ProfileState state) => switch (state) {
    ProfileInitial() ||
    ProfileLoading() ||
    ProfileLoaded() ||
    ProfileFailedSave() ||
    ProfileFailedStart() => true,
    _ => false,
  };

  static Future<void> _drain(ProfileCacheCubit cache) async {
    _draining = true;
    try {
      while (waiting.value.isNotEmpty) {
        final String uuid = waiting.value.first;
        waiting.value = List<String>.unmodifiable(waiting.value.skip(1));
        _current = uuid;
        _stopCurrent = false;
        final ProfileBloc bloc = cache.getProfileBloc(uuid);
        // A deleted connection's bloc is closed. One bad entry must not
        // leave the rest waiting forever.
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

  /// Starts [bloc] and waits until it is connected or has failed. The first
  /// start is sent synchronously.
  static Future<void> _start(ProfileBloc bloc) async {
    ProfileState state = bloc.state;
    if (state is ProfileInitial || state is ProfileLoading) {
      // Only rows that were shown have loaded, e.g. not the ones of a
      // collapsed folder or when started from the tray.
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

  /// The next state of [bloc] that passes [test], or null if the queue was
  /// cleared, the bloc closed, or it took too long.
  static Future<ProfileState?> _next(
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
