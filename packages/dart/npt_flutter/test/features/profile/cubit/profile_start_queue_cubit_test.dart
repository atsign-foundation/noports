import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile/bloc/profile_bloc.dart';
import 'package:npt_flutter/features/profile/cubit/profile_cache_cubit.dart';
import 'package:npt_flutter/features/profile/cubit/profile_start_queue_cubit.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';

class FakeProfileBloc extends Fake implements ProfileBloc {
  FakeProfileBloc(this.uuid, ProfileState state) : _state = state;

  @override
  final String uuid;

  ProfileState _state;
  bool _closed = false;
  final StreamController<ProfileState> _controller =
      StreamController<ProfileState>.broadcast();

  /// Every event the queue sent, in order.
  final List<ProfileEvent> events = <ProfileEvent>[];

  @override
  ProfileState get state => _state;

  @override
  Stream<ProfileState> get stream => _controller.stream;

  @override
  bool get isClosed => _closed;

  @override
  void add(ProfileEvent event) => events.add(event);

  @override
  Future<void> close() async {
    _closed = true;
    await _controller.close();
  }

  void moveTo(ProfileState state) {
    _state = state;
    _controller.add(state);
  }

  int get loads => events.whereType<ProfileLoadEvent>().length;
  int get starts => events.whereType<ProfileStartEvent>().length;
  int get stops => events.whereType<ProfileStopEvent>().length;
}

class FakeProfileCache extends Fake implements ProfileCacheCubit {
  final Map<String, FakeProfileBloc> blocs = <String, FakeProfileBloc>{};

  int _lookups = 0;
  int _lookupLimit = 1 << 30;

  /// Makes the lookups after the next [count] throw. A queue loop that should
  /// have stopped then fails the test instead of spinning forever, which no
  /// test timeout could interrupt.
  void failAfterLookups(int count) => _lookupLimit = _lookups + count;

  @override
  ProfileBloc getProfileBloc(String uuid) {
    if (++_lookups > _lookupLimit) {
      throw StateError('Looked up $uuid again and again');
    }
    return blocs.putIfAbsent(
      uuid,
      () => FakeProfileBloc(uuid, ProfileInitial(uuid)),
    );
  }
}

Profile profileOf(String uuid) => Profile(
  uuid,
  displayName: uuid,
  deviceName: 'device',
  remotePort: 22,
  localPort: 0,
);

ProfileState loaded(String uuid) =>
    ProfileLoaded(uuid, profile: profileOf(uuid));
ProfileState starting(String uuid) =>
    ProfileStarting(uuid, profile: profileOf(uuid));
ProfileState started(String uuid) =>
    ProfileStarted(uuid, profile: profileOf(uuid));
ProfileState stopping(String uuid) =>
    ProfileStopping(uuid, profile: profileOf(uuid));
ProfileState failedSave(String uuid) =>
    ProfileFailedSave(uuid, profile: profileOf(uuid));
ProfileState failedStart(String uuid) =>
    ProfileFailedStart(uuid, profile: profileOf(uuid), reason: 'no route');

/// Lets everything the cubit has scheduled run.
Future<void> settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeProfileCache cache;
  late ProfileStartQueueCubit cubit;

  FakeProfileBloc connection(String uuid, [ProfileState? state]) {
    final FakeProfileBloc bloc = cache.getProfileBloc(uuid) as FakeProfileBloc;
    if (state != null) bloc._state = state;
    return bloc;
  }

  setUp(() {
    cache = FakeProfileCache();
    cubit = ProfileStartQueueCubit(cache);
  });

  tearDown(() async {
    if (cubit.isClosed) return;
    cubit.clear();
    await cubit.close();
  });

  group('ProfileStartQueueState', () {
    test('knows which connections are waiting', () {
      const ProfileStartQueueState state = ProfileStartQueueState(<String>[
        'a',
        'b',
      ]);

      expect(state.isWaiting('a'), isTrue);
      expect(state.isWaiting('c'), isFalse);
    });

    test('is equal to another state with the same waiting list', () {
      expect(
        const ProfileStartQueueState(<String>['a']),
        const ProfileStartQueueState(<String>['a']),
      );
      expect(
        const ProfileStartQueueState(<String>['a']),
        isNot(const ProfileStartQueueState(<String>['b'])),
      );
    });

    test('prints the waiting list', () {
      expect(
        const ProfileStartQueueState(<String>['a', 'b']).toString(),
        'ProfileStartQueueState([a, b])',
      );
    });
  });

  group('one start at a time', () {
    test('nothing is waiting before anything is added', () {
      expect(cubit.state.waiting, isEmpty);
      expect(cubit.isWaiting('a'), isFalse);
    });

    test('starts the first connection and keeps the others waiting', () {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));

      cubit.add(<String>['a', 'b', 'c']);

      expect(a.starts, 1);
      expect(b.events, isEmpty);
      expect(c.events, isEmpty);
      expect(cubit.state.waiting, <String>['b', 'c']);
      expect(cubit.isWaiting('a'), isFalse);
      expect(cubit.isWaiting('b'), isTrue);
    });

    test(
      'starts the next one only after the previous one has connected',
      () async {
        final FakeProfileBloc a = connection('a', loaded('a'));
        final FakeProfileBloc b = connection('b', loaded('b'));
        final FakeProfileBloc c = connection('c', loaded('c'));
        cubit.add(<String>['a', 'b', 'c']);

        a.moveTo(starting('a'));
        await settle();
        expect(b.events, isEmpty);

        a.moveTo(started('a'));
        await settle();
        expect(b.starts, 1);
        expect(c.events, isEmpty);
        expect(cubit.state.waiting, <String>['c']);

        b.moveTo(starting('b'));
        b.moveTo(started('b'));
        await settle();
        expect(c.starts, 1);
        expect(cubit.state.waiting, isEmpty);
      },
    );

    test('goes on to the next one when a start fails', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      a.moveTo(starting('a'));
      a.moveTo(failedStart('a'));
      await settle();

      expect(b.starts, 1);
      expect(a.stops, 0);
    });

    test('starts again straight away once the queue has run dry', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      cubit.add(<String>['a']);
      a.moveTo(started('a'));
      await settle();

      final FakeProfileBloc d = connection('d', loaded('d'));
      cubit.add(<String>['d']);

      expect(d.starts, 1);
    });

    test(
      'starts the last connection again once the queue has run dry',
      () async {
        final FakeProfileBloc a = connection('a', loaded('a'));
        cubit.add(<String>['a']);
        a.moveTo(started('a'));
        await settle();

        a.moveTo(loaded('a'));
        cubit.add(<String>['a']);

        expect(a.starts, 2);
      },
    );

    test('queues more connections while one is starting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));
      cubit.add(<String>['a', 'b']);
      cubit.add(<String>['c']);

      expect(cubit.state.waiting, <String>['b', 'c']);
      a.moveTo(started('a'));
      await settle();
      b.moveTo(started('b'));
      await settle();

      expect(c.starts, 1);
    });

    test('hands out a waiting list that callers cannot change', () {
      connection('a', loaded('a'));
      connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      expect(() => cubit.state.waiting.add('x'), throwsUnsupportedError);
    });

    testWidgets('gives up on a start that never reports and moves on', (
      WidgetTester tester,
    ) async {
      final ProfileStartQueueCubit timed = ProfileStartQueueCubit(cache);
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      timed.add(<String>['a', 'b']);

      await tester.pump(const Duration(seconds: 30));
      expect(a.starts, 1);
      expect(b.events, isEmpty);

      await tester.pump(const Duration(seconds: 61));
      expect(b.starts, 1);

      timed.clear();
      await tester.pump();
      await timed.close();
    });
  });

  group('which connections are queued', () {
    final Map<String, ProfileState Function(String)> refused =
        <String, ProfileState Function(String)>{
          'starting': starting,
          'started': started,
          'stopping': stopping,
          'failed to load': ProfileFailedLoad.new,
        };
    final Map<String, ProfileState Function(String)> accepted =
        <String, ProfileState Function(String)>{
          'not loaded yet': ProfileInitial.new,
          'loading': ProfileLoading.new,
          'loaded': loaded,
          'failed to save': failedSave,
          'failed to start': failedStart,
        };

    for (final MapEntry<String, ProfileState Function(String)> entry
        in refused.entries) {
      test('does not queue a connection that is ${entry.key}', () {
        connection('first', loaded('first'));
        final FakeProfileBloc other = connection('x', entry.value('x'));

        cubit.add(<String>['first', 'x']);

        expect(cubit.state.waiting, isEmpty);
        expect(other.events, isEmpty);
      });
    }

    for (final MapEntry<String, ProfileState Function(String)> entry
        in accepted.entries) {
      test('queues a connection that is ${entry.key}', () {
        connection('first', loaded('first'));
        connection('x', entry.value('x'));

        cubit.add(<String>['first', 'x']);

        expect(cubit.state.waiting, <String>['x']);
      });
    }

    test('does not start anything when nothing can be queued', () {
      final FakeProfileBloc running = connection('a', started('a'));

      cubit.add(<String>['a']);

      expect(cubit.state.waiting, isEmpty);
      expect(running.events, isEmpty);
    });

    test(
      'skips a waiting connection started by hand before its turn',
      () async {
        final FakeProfileBloc a = connection('a', loaded('a'));
        final FakeProfileBloc b = connection('b', loaded('b'));
        final FakeProfileBloc c = connection('c', loaded('c'));
        cubit.add(<String>['a', 'b', 'c']);

        b.moveTo(started('b'));
        a.moveTo(started('a'));
        await settle();

        expect(b.events, isEmpty);
        expect(c.starts, 1);
      },
    );

    test('queues a connection once however often it is asked for', () {
      connection('first', loaded('first'));
      connection('x', loaded('x'));

      cubit.add(<String>['first', 'x', 'x']);
      cubit.add(<String>['x']);

      expect(cubit.state.waiting, <String>['x']);
    });

    test('does not start the connection that is starting a second time', () {
      final FakeProfileBloc a = connection('a', loaded('a'));
      cubit.add(<String>['a']);

      cubit.add(<String>['a']);

      expect(a.starts, 1);
      expect(cubit.state.waiting, isEmpty);
    });
  });

  group('loading before starting', () {
    test('loads a connection that was never shown, then starts it', () async {
      final FakeProfileBloc a = connection('a');

      cubit.add(<String>['a']);
      expect(a.events.single, isA<ProfileLoadEvent>());

      a.moveTo(ProfileLoading('a'));
      await settle();
      expect(a.starts, 0);

      a.moveTo(loaded('a'));
      await settle();
      expect(a.events.last, isA<ProfileStartEvent>());
      expect(a.loads, 1);
      expect(a.starts, 1);
    });

    test('waits for a connection that is already loading', () async {
      final FakeProfileBloc a = connection('a', ProfileLoading('a'));

      cubit.add(<String>['a']);
      expect(a.events, isEmpty);

      a.moveTo(loaded('a'));
      await settle();
      expect(a.loads, 0);
      expect(a.starts, 1);
    });

    test('moves on when a connection fails to load', () async {
      final FakeProfileBloc a = connection('a');
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      a.moveTo(ProfileLoading('a'));
      a.moveTo(ProfileFailedLoad('a'));
      await settle();

      expect(a.starts, 0);
      expect(b.starts, 1);
    });
  });

  group('clear', () {
    test('drops every connection that is waiting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));
      cubit.add(<String>['a', 'b', 'c']);

      cubit.clear();

      expect(cubit.state.waiting, isEmpty);
      expect(cubit.isWaiting('b'), isFalse);
      a.moveTo(started('a'));
      await settle();
      expect(b.events, isEmpty);
      expect(c.events, isEmpty);
    });

    test('does not stop the one that was already starting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      cubit.clear();
      a.moveTo(started('a'));
      await settle();

      expect(a.events.single, isA<ProfileStartEvent>());
    });

    test('lets a new start begin once the one starting is let go', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      cubit.add(<String>['a']);
      cubit.clear();
      await settle();

      final FakeProfileBloc d = connection('d', loaded('d'));
      cubit.add(<String>['d']);

      expect(d.starts, 1);
      expect(a.starts, 1);
    });

    test('starts connections added straight after it', () async {
      connection('a', loaded('a'));
      connection('b', loaded('b'));
      final FakeProfileBloc d = connection('d', loaded('d'));
      cubit.add(<String>['a', 'b']);

      cubit.clear();
      cubit.add(<String>['d']);
      await settle();

      expect(cubit.state.waiting, isEmpty);
      expect(d.starts, 1);
      expect(connection('b').events, isEmpty);
    });

    test('can be called again with nothing waiting', () async {
      cubit.clear();
      cubit.clear();
      await settle();

      expect(cubit.state.waiting, isEmpty);
    });
  });

  group('remove', () {
    test('drops a waiting connection and leaves the others', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));
      cubit.add(<String>['a', 'b', 'c']);

      cubit.remove(<String>['b']);

      expect(cubit.state.waiting, <String>['c']);
      a.moveTo(started('a'));
      await settle();
      expect(b.events, isEmpty);
      expect(c.starts, 1);
    });

    test(
      'leaves the queue as it was for connections it does not hold',
      () async {
        connection('a', loaded('a'));
        connection('b', loaded('b'));
        cubit.add(<String>['a', 'b']);
        final List<ProfileStartQueueState> states = <ProfileStartQueueState>[];
        final StreamSubscription<ProfileStartQueueState> sub = cubit.stream
            .listen(states.add);

        cubit.remove(<String>['zzz']);
        await settle();

        expect(states, isEmpty);
        expect(cubit.state.waiting, <String>['b']);
        await sub.cancel();
      },
    );

    test('stops the connection that is starting once it has started', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      cubit.remove(<String>['a']);
      a.moveTo(starting('a'));
      await settle();
      expect(a.stops, 0);

      a.moveTo(started('a'));
      await settle();
      expect(a.events.last, isA<ProfileStopEvent>());
      expect(a.stops, 1);
      expect(b.starts, 1);
    });

    test('does not stop the next connection once it has started', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      cubit.remove(<String>['a']);
      a.moveTo(started('a'));
      await settle();
      expect(a.stops, 1);
      expect(b.starts, 1);

      b.moveTo(started('b'));
      await settle();
      expect(b.stops, 0);
    });

    test('does not stop the connection if it failed to start', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      cubit.remove(<String>['a']);
      a.moveTo(failedStart('a'));
      await settle();

      expect(a.stops, 0);
      expect(b.starts, 1);
    });

    test('does not start a connection removed while it was loading', () async {
      final FakeProfileBloc a = connection('a');
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);
      expect(a.loads, 1);

      cubit.remove(<String>['a']);
      a.moveTo(ProfileLoading('a'));
      a.moveTo(loaded('a'));
      await settle();

      expect(a.starts, 0);
      expect(a.stops, 0);
      expect(b.starts, 1);
    });

    test('keeps the connection running when asked to start it again', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      cubit.remove(<String>['a']);
      cubit.add(<String>['a']);
      a.moveTo(started('a'));
      await settle();

      expect(a.stops, 0);
      expect(a.starts, 1);
      expect(cubit.isWaiting('a'), isFalse);
    });

    test(
      'still queues the others asked for along with the one it keeps',
      () async {
        final FakeProfileBloc a = connection('a', loaded('a'));
        final FakeProfileBloc x = connection('x', loaded('x'));
        cubit.add(<String>['a']);

        cubit.remove(<String>['a']);
        cubit.add(<String>['a', 'x']);
        expect(cubit.state.waiting, <String>['x']);
        a.moveTo(started('a'));
        await settle();

        expect(a.stops, 0);
        expect(x.starts, 1);
      },
    );

    test('only stops a connection it was asked to remove', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      cubit.add(<String>['a']);

      cubit.remove(<String>['b']);
      a.moveTo(started('a'));
      await settle();

      expect(a.stops, 0);
    });
  });

  group('deleted connections', () {
    test('are not queued', () {
      connection('first', loaded('first'));
      final FakeProfileBloc gone = connection('gone', loaded('gone'));
      gone._closed = true;

      cubit.add(<String>['first', 'gone']);

      expect(cubit.state.waiting, isEmpty);
      expect(gone.events, isEmpty);
    });

    test('do not start the queue on their own', () {
      final FakeProfileBloc gone = connection('gone', loaded('gone'));
      gone._closed = true;

      cubit.add(<String>['gone']);

      expect(cubit.state.waiting, isEmpty);
      expect(gone.events, isEmpty);
    });

    test('are skipped when deleted while waiting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));
      cubit.add(<String>['a', 'b', 'c']);

      await b.close();
      a.moveTo(started('a'));
      await settle();

      expect(b.events, isEmpty);
      expect(c.starts, 1);
      expect(cubit.state.waiting, isEmpty);
    });

    test('let the queue go on when deleted while starting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      await a.close();
      await settle();

      expect(b.starts, 1);
    });

    test('let the queue go on when deleted while loading', () async {
      final FakeProfileBloc a = connection('a');
      final FakeProfileBloc b = connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);

      await a.close();
      await settle();

      expect(a.starts, 0);
      expect(b.starts, 1);
    });
  });

  group('close', () {
    test('stops waiting for the connection that is starting', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      cubit.add(<String>['a']);

      await cubit.close();
      a.moveTo(started('a'));
      await settle();

      expect(cubit.isClosed, isTrue);
      expect(a.events.single, isA<ProfileStartEvent>());
    });

    test('starts no more connections when closed while others wait', () async {
      final FakeProfileBloc a = connection('a', loaded('a'));
      final FakeProfileBloc b = connection('b', loaded('b'));
      final FakeProfileBloc c = connection('c', loaded('c'));
      cubit.add(<String>['a', 'b', 'c']);
      cache.failAfterLookups(10);

      await cubit.close();
      await settle();

      expect(a.starts, 1);
      expect(b.events, isEmpty);
      expect(c.events, isEmpty);
    });

    // The test binding fails a test that ends with a timer still pending, and
    // the wait on a start that never reports ends with a 90 second timer.
    testWidgets('ends the wait on the connection that is starting', (
      WidgetTester tester,
    ) async {
      final ProfileStartQueueCubit closing = ProfileStartQueueCubit(cache);
      final FakeProfileBloc a = connection('a', loaded('a'));
      closing.add(<String>['a']);
      await tester.pump(const Duration(seconds: 1));
      expect(a.starts, 1);

      await closing.close();
      await tester.pump();
    });

    test('can be closed twice', () async {
      connection('a', loaded('a'));
      cubit.add(<String>['a']);

      await cubit.close();
      await cubit.close();

      expect(cubit.isClosed, isTrue);
    });

    test('can be cleared after it is closed', () async {
      connection('a', loaded('a'));
      connection('b', loaded('b'));
      cubit.add(<String>['a', 'b']);
      await cubit.close();

      expect(cubit.clear, returnsNormally);
      expect(cubit.clear, returnsNormally);
    });

    test('starts nothing that is added after it is closed', () async {
      final FakeProfileBloc x = connection('x', loaded('x'));
      await cubit.close();

      expect(() => cubit.add(<String>['x']), returnsNormally);
      expect(() => cubit.remove(<String>['x']), returnsNormally);
      await settle();

      expect(x.events, isEmpty);
    });
  });
}
