import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import 'profile_bloc_test.mocks.dart';

@GenerateMocks([
  ProfileRepository,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileBloc Tests', () {
    late ProfileBloc profileBloc;
    late MockProfileRepository mockRepository;

    const testUuid = 'test-uuid-123';
    const testProfile = Profile(
      testUuid,
      displayName: 'Test Profile',
      sshnpdAtsign: '@test_device',
      deviceName: 'test-device',
      remotePort: 22,
      localPort: 2222,
      relayAtsign: '@relay_test',
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
          when(mockRepository.getProfile(testUuid, useCache: true))
              .thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileFailedLoad when profile is null',
        build: () {
          when(mockRepository.getProfile(testUuid, useCache: true))
              .thenAnswer((_) async => null);
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
          when(mockRepository.getProfile(testUuid, useCache: true))
              .thenThrow(Exception('Repository error'));
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
          when(mockRepository.getProfile(testUuid, useCache: false))
              .thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent(useCache: false)),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
        ],
        verify: (_) {
          verify(mockRepository.getProfile(testUuid, useCache: false))
              .called(1);
        },
      );
    });

    group('ProfileLoadOrCreateEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileLoaded when profile exists',
        build: () {
          when(mockRepository.getProfile(testUuid))
              .thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadOrCreateEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should create default profile when profile is null and no copyFrom',
        build: () {
          when(mockRepository.getProfile(testUuid))
              .thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadOrCreateEvent()),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid,
              profile: Profile(
                testUuid,
                displayName: '',
                sshnpdAtsign: '',
                relayAtsign: '',
                deviceName: '',
                remotePort: 3389,
                localPort: 0,
              )),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should create profile from copyFrom when provided',
        build: () {
          when(mockRepository.getProfile(testUuid))
              .thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) =>
            bloc.add(const ProfileLoadOrCreateEvent(copyFrom: testProfile)),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid,
              profile: testProfile.copyWith(uuid: testUuid)),
        ],
      );
    });

    group('ProfileEditEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileLoaded',
        build: () => profileBloc,
        seed: () => const ProfileLoaded(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile =
              testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(testUuid,
              profile: testProfile.copyWith(displayName: 'Edited Profile')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileFailedSave',
        build: () => profileBloc,
        seed: () => const ProfileFailedSave(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile =
              testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(testUuid,
              profile: testProfile.copyWith(displayName: 'Edited Profile')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should not emit anything when current state is not ProfileLoaded or ProfileFailedSave',
        build: () => profileBloc,
        seed: () => const ProfileLoading(testUuid),
        act: (bloc) {
          final editedProfile =
              testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [],
      );
    });

    group('State Types', () {
      test(
          'ProfileLoadedState should include ProfileLoaded and ProfileFailedSave',
          () {
        const loadedState = ProfileLoaded(testUuid, profile: testProfile);
        const failedSaveState =
            ProfileFailedSave(testUuid, profile: testProfile);

        expect(loadedState, isA<ProfileLoadedState>());
        expect(failedSaveState, isA<ProfileLoadedState>());
      });

      test('ProfileStarting should include status', () {
        const status = 'Connecting...';
        const startingState =
            ProfileStarting(testUuid, profile: testProfile, status: status);

        expect(startingState.status, equals(status));
        expect(startingState.props, contains(status));
      });

      test('ProfileFailedStart should include reason', () {
        const reason = 'Connection failed';
        const failedStartState =
            ProfileFailedStart(testUuid, profile: testProfile, reason: reason);

        expect(failedStartState.reason, equals(reason));
      });
    });

    group('Event toString Methods', () {
      test(
          'Event toString methods should provide proper string representations',
          () {
        const loadEvent = ProfileLoadEvent(useCache: false);
        const createEvent = ProfileLoadOrCreateEvent();
        const editEvent = ProfileEditEvent(profile: testProfile);
        const startEvent = ProfileStartEvent();
        const stopEvent = ProfileStopEvent();

        expect(loadEvent.toString(), contains('useCache: false'));
        expect(createEvent.toString(), equals('ProfileLoadOrCreateEvent'));
        expect(editEvent.toString(), contains('profile: $testProfile'));
        expect(startEvent.toString(), equals('ProfileStartEvent'));
        expect(stopEvent.toString(), equals('ProfileStopEvent'));
      });
    });

    group('State toString Methods', () {
      test('State toString methods should include relevant information', () {
        const initialState = ProfileInitial(testUuid);
        const loadingState = ProfileLoading(testUuid);
        const failedLoadState = ProfileFailedLoad(testUuid);
        const loadedState = ProfileLoaded(testUuid, profile: testProfile);
        const failedSaveState =
            ProfileFailedSave(testUuid, profile: testProfile);

        expect(initialState.toString(), contains(testUuid));
        expect(loadingState.toString(), contains(testUuid));
        expect(failedLoadState.toString(), contains(testUuid));
        expect(loadedState.toString(),
            allOf(contains(testUuid), contains('profile: $testProfile')));
        expect(failedSaveState.toString(),
            allOf(contains(testUuid), contains('profile: $testProfile')));
      });
    });

    group('Event and State Props', () {
      test('Event props should contain appropriate data for equality', () {
        const loadEvent = ProfileLoadEvent();
        const createEvent = ProfileLoadOrCreateEvent();
        const editEvent = ProfileEditEvent(profile: testProfile);
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
        const loadedState = ProfileLoaded(testUuid, profile: testProfile);
        const failedSaveState =
            ProfileFailedSave(testUuid, profile: testProfile);

        expect(initialState.props, contains(testUuid));
        expect(loadingState.props, contains(testUuid));
        expect(failedLoadState.props, contains(testUuid));
        expect(loadedState.props,
            allOf(contains(testUuid), contains(testProfile)));
        expect(failedSaveState.props,
            allOf(contains(testUuid), contains(testProfile)));
      });
    });

    group('Complex Scenarios', () {
      blocTest<ProfileBloc, ProfileState>(
        'should handle multiple rapid events correctly',
        build: () {
          when(mockRepository.getProfile(testUuid, useCache: true))
              .thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) {
          bloc.add(const ProfileLoadEvent());
          bloc.add(ProfileEditEvent(
              profile: testProfile.copyWith(displayName: 'New Name')));
        },
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
          ProfileLoaded(testUuid,
              profile: testProfile.copyWith(displayName: 'New Name')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should handle ProfileLoadOrCreateEvent with copyFrom after failed load',
        build: () {
          when(mockRepository.getProfile(testUuid))
              .thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(ProfileLoadOrCreateEvent(
          copyFrom: testProfile.copyWith(displayName: 'Original'),
        )),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid,
              profile: testProfile.copyWith(displayName: 'Original')),
        ],
      );
    });
  });
}
