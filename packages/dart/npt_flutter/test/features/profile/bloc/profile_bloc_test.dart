import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';
import 'package:socket_connector/socket_connector.dart';

import 'profile_bloc_test.mocks.dart';

/// How long a faked [SocketConnector] waits before its grace period timer
/// fires. Short so it drains inside a test rather than outliving it.
const connectorGracePeriod = Duration(milliseconds: 20);

@GenerateMocks([ProfileRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileBloc Tests', () {
    late ProfileBloc profileBloc;
    late MockProfileRepository mockRepository;

    const testUuid = 'test-uuid-123';
    final testProfile = Profile(
      testUuid,
      displayName: 'Test Profile',
      sshnpdAtsign: '@test_device'.toAtsign(),
      deviceName: 'test-device',
      remotePort: 22,
      localPort: 2222,
      relayAtsign: '@relay_test'.toAtsign(),
    );

    setUp(() {
      mockRepository = MockProfileRepository();
      profileBloc = ProfileBloc(mockRepository, testUuid);
    });

    tearDown(() {
      profileBloc.close();
    });

    group('Initial State', () {
      test('should have ProfileInitial as initial state', () {
        expect(profileBloc.state, equals(const ProfileInitial(testUuid)));
      });

      test('should have correct uuid in initial state', () {
        expect(profileBloc.state.uuid, equals(testUuid));
      });
    });

    group('ProfileLoadEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileLoaded when profile is loaded successfully',
        build: () {
          when(
            mockRepository.getProfile(testUuid, useCache: true),
          ).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileFailedLoad when profile is null',
        build: () {
          when(
            mockRepository.getProfile(testUuid, useCache: true),
          ).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileFailedLoad(testUuid),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileFailedLoad when repository throws exception',
        build: () {
          when(
            mockRepository.getProfile(testUuid, useCache: true),
          ).thenThrow(Exception('Repository error'));
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileFailedLoad(testUuid),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should use cache parameter correctly',
        build: () {
          when(
            mockRepository.getProfile(testUuid, useCache: false),
          ).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent(useCache: false)),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile),
        ],
        verify: (_) {
          verify(
            mockRepository.getProfile(testUuid, useCache: false),
          ).called(1);
        },
      );
    });

    group('ProfileLoadOrCreateEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileLoaded when profile exists',
        build: () {
          when(
            mockRepository.getProfile(testUuid),
          ).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadOrCreateEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should create default profile when profile is null and no copyFrom',
        build: () {
          when(
            mockRepository.getProfile(testUuid),
          ).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadOrCreateEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(
            testUuid,
            profile: Profile(
              testUuid,
              displayName: '',

              deviceName: '',
              remotePort: 3389,
              localPort: 0,
            ),
          ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should create profile from copyFrom when provided',
        build: () {
          when(
            mockRepository.getProfile(testUuid),
          ).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) =>
            bloc.add(ProfileLoadOrCreateEvent(copyFrom: testProfile)),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(
            testUuid,
            profile: testProfile.copyWith(uuid: testUuid),
          ),
        ],
      );
    });

    group('ProfileEditEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileLoaded',
        build: () => profileBloc,
        seed: () => ProfileLoaded(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(
            displayName: 'Edited Profile',
          );
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(
            testUuid,
            profile: testProfile.copyWith(displayName: 'Edited Profile'),
          ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileFailedSave',
        build: () => profileBloc,
        seed: () => ProfileFailedSave(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(
            displayName: 'Edited Profile',
          );
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(
            testUuid,
            profile: testProfile.copyWith(displayName: 'Edited Profile'),
          ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should not emit anything when current state is not ProfileLoaded or ProfileFailedSave',
        build: () => profileBloc,
        seed: () => const ProfileLoading(testUuid),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(
            displayName: 'Edited Profile',
          );
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [],
      );
    });

    group('State Types', () {
      test(
        'ProfileLoadedState should include ProfileLoaded and ProfileFailedSave',
        () {
          final loadedState = ProfileLoaded(testUuid, profile: testProfile);
          final failedSaveState = ProfileFailedSave(
            testUuid,
            profile: testProfile,
          );

          expect(loadedState, isA<ProfileLoadedState>());
          expect(failedSaveState, isA<ProfileLoadedState>());
        },
      );

      test('ProfileStarting should include status', () {
        const status = 'Connecting...';
        final startingState = ProfileStarting(
          testUuid,
          profile: testProfile,
          status: status,
        );

        expect(startingState.status, equals(status));
        expect(startingState.props, contains(status));
      });

      test('ProfileFailedStart should include reason', () {
        const reason = 'Connection failed';
        final failedStartState = ProfileFailedStart(
          testUuid,
          profile: testProfile,
          reason: reason,
        );

        expect(failedStartState.reason, equals(reason));
      });
    });

    group('Event toString Methods', () {
      test(
        'Event toString methods should provide proper string representations',
        () {
          const loadEvent = ProfileLoadEvent(useCache: false);
          const createEvent = ProfileLoadOrCreateEvent();
          final editEvent = ProfileEditEvent(profile: testProfile);
          const startEvent = ProfileStartEvent();
          const stopEvent = ProfileStopEvent();

          expect(loadEvent.toString(), contains('useCache: false'));
          expect(createEvent.toString(), equals('ProfileLoadOrCreateEvent'));
          expect(editEvent.toString(), contains('profile: $testProfile'));
          expect(startEvent.toString(), equals('ProfileStartEvent'));
          expect(stopEvent.toString(), equals('ProfileStopEvent'));
        },
      );
    });

    group('State toString Methods', () {
      test('State toString methods should include relevant information', () {
        const initialState = ProfileInitial(testUuid);
        const loadingState = ProfileLoading(testUuid);
        const failedLoadState = ProfileFailedLoad(testUuid);
        final loadedState = ProfileLoaded(testUuid, profile: testProfile);
        final failedSaveState = ProfileFailedSave(
          testUuid,
          profile: testProfile,
        );

        expect(initialState.toString(), contains(testUuid));
        expect(loadingState.toString(), contains(testUuid));
        expect(failedLoadState.toString(), contains(testUuid));
        expect(
          loadedState.toString(),
          allOf(contains(testUuid), contains('profile: $testProfile')),
        );
        expect(
          failedSaveState.toString(),
          allOf(contains(testUuid), contains('profile: $testProfile')),
        );
      });
    });

    group('Event and State Props', () {
      test('Event props should contain appropriate data for equality', () {
        const loadEvent = ProfileLoadEvent();
        const createEvent = ProfileLoadOrCreateEvent();
        final editEvent = ProfileEditEvent(profile: testProfile);
        const startEvent = ProfileStartEvent();
        const stopEvent = ProfileStopEvent();

        expect(loadEvent.props, isEmpty);
        expect(createEvent.props, isEmpty);
        expect(editEvent.props, contains(testProfile));
        expect(startEvent.props, isEmpty);
        expect(stopEvent.props, isEmpty);
      });

      test('State props should contain appropriate data for equality', () {
        const initialState = ProfileInitial(testUuid);
        const loadingState = ProfileLoading(testUuid);
        const failedLoadState = ProfileFailedLoad(testUuid);
        final loadedState = ProfileLoaded(testUuid, profile: testProfile);
        final failedSaveState = ProfileFailedSave(
          testUuid,
          profile: testProfile,
        );

        expect(initialState.props, contains(testUuid));
        expect(loadingState.props, contains(testUuid));
        expect(failedLoadState.props, contains(testUuid));
        expect(
          loadedState.props,
          allOf(contains(testUuid), contains(testProfile)),
        );
        expect(
          failedSaveState.props,
          allOf(contains(testUuid), contains(testProfile)),
        );
      });
    });

    group('Complex Scenarios', () {
      blocTest<ProfileBloc, ProfileState>(
        'should handle multiple rapid events correctly',
        build: () {
          when(
            mockRepository.getProfile(testUuid, useCache: true),
          ).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) {
          bloc.add(const ProfileLoadEvent());
          bloc.add(
            ProfileEditEvent(
              profile: testProfile.copyWith(displayName: 'New Name'),
            ),
          );
        },
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile),
          ProfileLoaded(
            testUuid,
            profile: testProfile.copyWith(displayName: 'New Name'),
          ),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should handle ProfileLoadOrCreateEvent with copyFrom after failed load',
        build: () {
          when(
            mockRepository.getProfile(testUuid),
          ).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(
          ProfileLoadOrCreateEvent(
            copyFrom: testProfile.copyWith(displayName: 'Original'),
          ),
        ),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(
            testUuid,
            profile: testProfile.copyWith(displayName: 'Original'),
          ),
        ],
      );
    });

    /// Regression coverage for
    /// https://github.com/atsign-foundation/noports/issues/2789 - a startup
    /// failure used to park `_onStart` forever on `await npt.done`, leaving the
    /// profile stuck on ProfileStarting with no way to stop it.
    group('ProfileStartEvent - keep-alive loop', () {
      late FakeSettingsBloc fakeSettingsBloc;
      late ProfilesRunningCubit runningCubit;
      late List<FakeNpt> attempts;

      final testSettings = Settings(
        relayAtsign: '@rv_test'.toAtsign(),
        overrideRelay: false,
        viewLayout: PreferredViewLayout.minimal,
        darkMode: false,
        language: Language.english,
      );

      setUp(() {
        fakeSettingsBloc = FakeSettingsBloc(
          SettingsLoaded(settings: testSettings),
        );
        runningCubit = ProfilesRunningCubit();
        attempts = [];
      });

      /// Builds a bloc wired to [attempts] and pumps it inside the providers
      /// that ProfileBloc reads off [App.navState], then drives it to
      /// ProfileLoaded so that a ProfileStartEvent will be accepted.
      Future<ProfileBloc> pumpLoadedBloc(
        WidgetTester tester, {
        required Profile profile,
        required FakeNpt Function() createNpt,
      }) async {
        final bloc = ProfileBloc(
          mockRepository,
          testUuid,
          getAtClient: FakeAtClient.new,
          retryDelay: const Duration(milliseconds: 10),
          createNpt: ({required atClient, required params}) {
            final npt = createNpt();
            attempts.add(npt);
            return npt;
          },
        );
        addTearDown(bloc.close);

        await tester.pumpWidget(
          MaterialApp(
            navigatorKey: App.navState,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                // App.log -> LogsCubit -> EnableLoggingCubit
                BlocProvider<LogsCubit>(create: (_) => LogsCubit()),
                BlocProvider<EnableLoggingCubit>(
                  create: (_) => EnableLoggingCubit(),
                ),
                BlocProvider<ProfileBloc>.value(value: bloc),
                BlocProvider<SettingsBloc>.value(value: fakeSettingsBloc),
                BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
              ],
              child: const SizedBox.shrink(),
            ),
          ),
        );

        when(
          mockRepository.getProfile(testUuid, useCache: true),
        ).thenAnswer((_) async => profile);
        bloc.add(const ProfileLoadEvent());
        await tester.pumpAndSettle();
        expect(bloc.state, isA<ProfileLoaded>());
        return bloc;
      }

      /// Pumps until [condition] holds. Fails fast rather than hanging the
      /// suite, which is the failure mode this group exists to catch.
      Future<void> pumpUntil(
        WidgetTester tester,
        bool Function() condition, {
        String? reason,
      }) async {
        for (var i = 0; i < 500 && !condition(); i++) {
          await tester.pump(const Duration(milliseconds: 10));
        }
        expect(condition(), isTrue, reason: reason);
      }

      testWidgets('startup failure without keep-alive fails and closes the npt', (
        tester,
      ) async {
        final bloc = await pumpLoadedBloc(
          tester,
          profile: testProfile,
          createNpt: () =>
              FakeNpt(startupError: TimeoutException('feature check timed out')),
        );

        bloc.add(const ProfileStartEvent());
        await pumpUntil(tester, () => bloc.state is ProfileFailedStart);

        expect(attempts, hasLength(1));
        expect(
          attempts.single.closeCalled,
          isTrue,
          reason: 'npt must be closed on the failure path, otherwise nothing '
              'ever completes its done future',
        );
      });

      testWidgets('successful start caches the connector and stops cleanly', (
        tester,
      ) async {
        final bloc = await pumpLoadedBloc(
          tester,
          profile: testProfile,
          createNpt: FakeNpt.new,
        );

        bloc.add(const ProfileStartEvent());
        await pumpUntil(tester, () => bloc.state is ProfileStarted);

        expect(attempts, hasLength(1));
        expect(
          runningCubit.state.socketConnectors,
          contains(testUuid),
          reason: 'a started session must be reachable for a later stop',
        );

        bloc.add(const ProfileStopEvent());
        await pumpUntil(tester, () => bloc.state is ProfileLoaded);

        expect(
          runningCubit.state.socketConnectors,
          isNot(contains(testUuid)),
          reason: 'stopping must release the cached connector',
        );
        expect(attempts.single.closeCalled, isTrue);

        // Drain the connector's grace period timer before teardown
        await tester.pump(connectorGracePeriod * 2);
      });

      testWidgets('startup failure with keep-alive retries', (tester) async {
        final bloc = await pumpLoadedBloc(
          tester,
          profile: testProfile.copyWith(keepAlive: true),
          createNpt: () =>
              FakeNpt(startupError: TimeoutException('feature check timed out')),
        );

        bloc.add(const ProfileStartEvent());
        await pumpUntil(
          tester,
          () => attempts.length >= 2,
          reason: 'keep-alive must keep retrying after a failed attempt',
        );
        expect(bloc.state, isA<ProfileStarting>());

        // Wind the loop down so the test doesn't leave timers pending
        bloc.add(const ProfileStopEvent());
        await pumpUntil(tester, () => bloc.state is ProfileLoaded);
      });

      testWidgets('stop during ProfileStarting exits the loop', (tester) async {
        final bloc = await pumpLoadedBloc(
          tester,
          profile: testProfile.copyWith(keepAlive: true),
          createNpt: () => FakeNpt(
            // Mirrors a real in-flight startup: close() doesn't abort it, it
            // settles a little later on its own timeout
            startupDelay: const Duration(milliseconds: 50),
            startupError: TimeoutException('feature check timed out'),
          ),
        );

        bloc.add(const ProfileStartEvent());
        await pumpUntil(tester, () => attempts.isNotEmpty);
        expect(bloc.state, isA<ProfileStarting>());

        bloc.add(const ProfileStopEvent());
        await pumpUntil(tester, () => bloc.state is ProfileLoaded);

        final attemptsAtStop = attempts.length;
        await tester.pump(const Duration(milliseconds: 200));
        expect(
          attempts,
          hasLength(attemptsAtStop),
          reason: 'no further attempts may be made after a stop',
        );
      });
    });
  });
}

/// Hand written rather than generated so that this test isn't coupled to
/// whichever at_client version happens to be resolved - ProfileBloc only ever
/// asks an AtClient for these two things.
class FakeAtClient implements AtClient {
  @override
  String? getCurrentAtSign() => '@alice';

  @override
  AtClientPreference? getPreferences() =>
      AtClientPreference()..rootDomain = 'root.atsign.org';

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} is not faked');
}

/// A [SettingsBloc] pinned to one state - ProfileBloc only reads `.state`.
class FakeSettingsBloc extends SettingsBloc {
  FakeSettingsBloc(this.fixedState) : super(const SettingsRepository());

  final SettingsState fixedState;

  @override
  SettingsState get state => fixedState;
}

/// Stands in for a real [Npt] so the start/retry loop can be driven without a
/// daemon. Records whether [close] was called - that is what releases [done].
class FakeNpt implements Npt {
  FakeNpt({
    this.startupError,
    this.startupDelay = Duration.zero,
    this.connectorTimeout = connectorGracePeriod,
  });

  final Object? startupError;
  final Duration startupDelay;

  /// [SocketConnector]'s constructor arms a grace period timer (30s by
  /// default) which nothing cancels, and a widget test fails if a timer is
  /// still pending at teardown. Keep it short enough to drain inside a test.
  final Duration connectorTimeout;

  SocketConnector? _connector;

  /// Null until a startup actually succeeds - the failure tests must never arm
  /// that timer.
  SocketConnector? get connector => _connector;

  final Completer<void> _completer = Completer<void>();
  final StreamController<String> _progress =
      StreamController<String>.broadcast();
  final StreamController<String> _log = StreamController<String>.broadcast();

  bool closeCalled = false;

  @override
  Stream<String>? get progressStream => _progress.stream;

  @override
  Stream<String>? get logStream => _log.stream;

  @override
  Future get done => _completer.future;

  @override
  Future<void> close() async {
    closeCalled = true;
    if (!_completer.isCompleted) _completer.complete();
  }

  @override
  Future<SocketConnector> runInline({int? localRvPort}) async {
    if (startupDelay > Duration.zero) await Future.delayed(startupDelay);
    if (startupError != null) throw startupError!;
    return _connector ??= SocketConnector(timeout: connectorTimeout);
  }

  @override
  Future<int> run() => throw UnimplementedError();

  @override
  AtClient get atClient => throw UnimplementedError();

  @override
  NptParams get params => throw UnimplementedError();

  @override
  String get sessionId => 'fake-session-id';

  @override
  String get namespace => 'fake.namespace';
}
