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
          when(mockRepository.getProfile(testUuid, useCache: true)).thenAnswer((_) async => testProfile);
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
          when(mockRepository.getProfile(testUuid, useCache: true)).thenAnswer((_) async => null);
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
          when(mockRepository.getProfile(testUuid, useCache: true)).thenThrow(Exception('Repository error'));
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
          when(mockRepository.getProfile(testUuid, useCache: false)).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadEvent(useCache: false)),
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
        ],
        verify: (_) {
          verify(mockRepository.getProfile(testUuid, useCache: false)).called(1);
        },
      );
    });

    group('ProfileLoadOrCreateEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoading then ProfileLoaded when profile exists',
        build: () {
          when(mockRepository.getProfile(testUuid)).thenAnswer((_) async => testProfile);
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
          when(mockRepository.getProfile(testUuid)).thenAnswer((_) async => null);
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
          when(mockRepository.getProfile(testUuid)).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(const ProfileLoadOrCreateEvent(copyFrom: testProfile)),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile.copyWith(uuid: testUuid)),
        ],
      );
    });

    group('ProfileEditEvent', () {
      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileLoaded',
        build: () => profileBloc,
        seed: () => const ProfileLoaded(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(testUuid, profile: testProfile.copyWith(displayName: 'Edited Profile')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should emit ProfileLoaded when current state is ProfileFailedSave',
        build: () => profileBloc,
        seed: () => const ProfileFailedSave(testUuid, profile: testProfile),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [
          ProfileLoaded(testUuid, profile: testProfile.copyWith(displayName: 'Edited Profile')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should not emit anything when current state is not ProfileLoaded or ProfileFailedSave',
        build: () => profileBloc,
        seed: () => const ProfileLoading(testUuid),
        act: (bloc) {
          final editedProfile = testProfile.copyWith(displayName: 'Edited Profile');
          bloc.add(ProfileEditEvent(profile: editedProfile));
        },
        expect: () => [],
      );
    });

    group('State Types', () {
      test('ProfileLoadedState should include ProfileLoaded and ProfileFailedSave', () {
        const loadedState = ProfileLoaded(testUuid, profile: testProfile);
        const failedSaveState = ProfileFailedSave(testUuid, profile: testProfile);

        expect(loadedState, isA<ProfileLoadedState>());
        expect(failedSaveState, isA<ProfileLoadedState>());
      });

      test('ProfileStarting should include status', () {
        const status = 'Connecting...';
        const startingState = ProfileStarting(testUuid, profile: testProfile, status: status);

        expect(startingState.status, equals(status));
        expect(startingState.props, contains(status));
      });

      test('ProfileFailedStart should include reason', () {
        const reason = 'Connection failed';
        const failedStartState = ProfileFailedStart(testUuid, profile: testProfile, reason: reason);

        expect(failedStartState.reason, equals(reason));
      });
    });

    group('Event toString Methods', () {
      test('ProfileLoadEvent toString should include useCache', () {
        const event = ProfileLoadEvent(useCache: false);
        expect(event.toString(), contains('useCache: false'));
      });

      test('ProfileLoadOrCreateEvent toString should be correct', () {
        const event = ProfileLoadOrCreateEvent();
        expect(event.toString(), equals('ProfileLoadOrCreateEvent'));
      });

      test('ProfileEditEvent toString should include profile', () {
        const event = ProfileEditEvent(profile: testProfile);
        expect(event.toString(), contains('profile: $testProfile'));
      });

      test('ProfileStartEvent toString should be correct', () {
        const event = ProfileStartEvent();
        expect(event.toString(), equals('ProfileStartEvent'));
      });

      test('ProfileStopEvent toString should be correct', () {
        const event = ProfileStopEvent();
        expect(event.toString(), equals('ProfileStopEvent'));
      });
    });

    group('State toString Methods', () {
      test('ProfileInitial toString should include uuid', () {
        const state = ProfileInitial(testUuid);
        expect(state.toString(), contains(testUuid));
      });

      test('ProfileLoading toString should include uuid', () {
        const state = ProfileLoading(testUuid);
        expect(state.toString(), contains(testUuid));
      });

      test('ProfileFailedLoad toString should include uuid', () {
        const state = ProfileFailedLoad(testUuid);
        expect(state.toString(), contains(testUuid));
      });

      test('ProfileLoaded toString should include uuid and profile', () {
        const state = ProfileLoaded(testUuid, profile: testProfile);
        expect(state.toString(), contains(testUuid));
        expect(state.toString(), contains('profile: $testProfile'));
      });

      test('ProfileFailedSave toString should include uuid and profile', () {
        const state = ProfileFailedSave(testUuid, profile: testProfile);
        expect(state.toString(), contains(testUuid));
        expect(state.toString(), contains('profile: $testProfile'));
      });
    });

    group('Event Props', () {
      test('ProfileLoadEvent props should be empty', () {
        const event = ProfileLoadEvent();
        expect(event.props, isEmpty);
      });

      test('ProfileLoadOrCreateEvent props should be empty', () {
        const event = ProfileLoadOrCreateEvent();
        expect(event.props, isEmpty);
      });

      test('ProfileEditEvent props should include profile', () {
        const event = ProfileEditEvent(profile: testProfile);
        expect(event.props, contains(testProfile));
      });

      test('ProfileStartEvent props should be empty', () {
        const event = ProfileStartEvent();
        expect(event.props, isEmpty);
      });

      test('ProfileStopEvent props should be empty', () {
        const event = ProfileStopEvent();
        expect(event.props, isEmpty);
      });
    });

    group('State Props', () {
      test('ProfileInitial props should contain uuid', () {
        const state = ProfileInitial(testUuid);
        expect(state.props, contains(testUuid));
      });

      test('ProfileLoading props should contain uuid', () {
        const state = ProfileLoading(testUuid);
        expect(state.props, contains(testUuid));
      });

      test('ProfileFailedLoad props should contain uuid', () {
        const state = ProfileFailedLoad(testUuid);
        expect(state.props, contains(testUuid));
      });

      test('ProfileLoaded props should contain uuid and profile', () {
        const state = ProfileLoaded(testUuid, profile: testProfile);
        expect(state.props, contains(testUuid));
        expect(state.props, contains(testProfile));
      });

      test('ProfileFailedSave props should contain uuid and profile', () {
        const state = ProfileFailedSave(testUuid, profile: testProfile);
        expect(state.props, contains(testUuid));
        expect(state.props, contains(testProfile));
      });
    });

    group('Complex Scenarios', () {
      blocTest<ProfileBloc, ProfileState>(
        'should handle multiple rapid events correctly',
        build: () {
          when(mockRepository.getProfile(testUuid, useCache: true)).thenAnswer((_) async => testProfile);
          return profileBloc;
        },
        act: (bloc) {
          bloc.add(const ProfileLoadEvent());
          bloc.add(ProfileEditEvent(profile: testProfile.copyWith(displayName: 'New Name')));
        },
        expect: () => [
          const ProfileLoading(testUuid),
          const ProfileLoaded(testUuid, profile: testProfile),
          ProfileLoaded(testUuid, profile: testProfile.copyWith(displayName: 'New Name')),
        ],
      );

      blocTest<ProfileBloc, ProfileState>(
        'should handle ProfileLoadOrCreateEvent with copyFrom after failed load',
        build: () {
          when(mockRepository.getProfile(testUuid)).thenAnswer((_) async => null);
          return profileBloc;
        },
        act: (bloc) => bloc.add(ProfileLoadOrCreateEvent(
          copyFrom: testProfile.copyWith(displayName: 'Original'),
        )),
        expect: () => [
          const ProfileLoading(testUuid),
          ProfileLoaded(testUuid, profile: testProfile.copyWith(displayName: 'Original')),
        ],
      );
    });
  });
}
