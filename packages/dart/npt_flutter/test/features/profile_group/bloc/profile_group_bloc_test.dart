import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/repository/profile_group_repository.dart';

class FakeProfileGroupRepository extends ProfileGroupRepository {
  ProfileGroupData? loadResult;
  bool throwOnLoad = false;
  bool throwOnPut = false;
  final List<ProfileGroupData> puts = <ProfileGroupData>[];

  @override
  Future<ProfileGroupData?> getProfileGroups() async {
    if (throwOnLoad) throw Exception('load failed');
    return loadResult;
  }

  @override
  Future<bool> putProfileGroups(ProfileGroupData data) async {
    puts.add(data);
    if (throwOnPut) throw Exception('put failed');
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ProfileGroup groupA = ProfileGroup(
    uuid: 'ga',
    name: 'A',
    profileIds: <String>['p1', 'p2'],
  );
  const ProfileGroup groupB = ProfileGroup(
    uuid: 'gb',
    name: 'B',
    profileIds: <String>['p3'],
  );
  const ProfileGroupData loadedData = ProfileGroupData(
    groups: <ProfileGroup>[groupA, groupB],
  );

  late FakeProfileGroupRepository repo;
  late ProfileGroupBloc bloc;

  setUp(() {
    repo = FakeProfileGroupRepository();
    bloc = ProfileGroupBloc(repo);
  });

  tearDown(() => bloc.close());

  test('initial state is ProfileGroupsInitial', () {
    expect(bloc.state, const ProfileGroupsInitial());
  });

  test('clearAll resets to initial', () {
    bloc.emit(const ProfileGroupsLoaded(loadedData));
    bloc.clearAll();
    expect(bloc.state, const ProfileGroupsInitial());
  });

  group('ProfileGroupLoadEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'emits loading then loaded with repository data',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileGroupBloc bloc) => bloc.add(const ProfileGroupLoadEvent()),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoading(),
        const ProfileGroupsLoaded(loadedData),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'emits failed load when repository returns null',
      build: () => bloc,
      act: (ProfileGroupBloc bloc) => bloc.add(const ProfileGroupLoadEvent()),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoading(),
        const ProfileGroupsFailedLoad(),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'emits failed load when repository throws',
      build: () {
        repo.throwOnLoad = true;
        return bloc;
      },
      act: (ProfileGroupBloc bloc) => bloc.add(const ProfileGroupLoadEvent()),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoading(),
        const ProfileGroupsFailedLoad(),
      ],
    );
  });

  group('ProfileGroupCreateEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'appends a new group and claims the given profiles from other groups',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupCreateEvent(
          name: 'C',
          profileIds: <String>['p2', 'p4', 'p4'],
        ),
      ),
      verify: (ProfileGroupBloc bloc) {
        final ProfileGroupsLoaded state = bloc.state as ProfileGroupsLoaded;
        expect(state.groups.length, 3);
        expect(state.groups[0].profileIds, <String>['p1']);
        expect(state.groups[1], groupB);
        final ProfileGroup created = state.groups[2];
        expect(created.name, 'C');
        expect(created.uuid, isNotEmpty);
        expect(created.profileIds, <String>['p2', 'p4']);
        expect(repo.puts.single, state.data);
      },
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'is ignored when not loaded',
      build: () => bloc,
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupCreateEvent(name: 'C')),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupRenameEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'renames the matching group only',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupRenameEvent(groupId: 'gb', name: 'Renamed'),
      ),
      expect: () => <ProfileGroupState>[
        ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              groupA,
              groupB.copyWith(name: 'Renamed'),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'does nothing for an unknown group',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupRenameEvent(groupId: 'nope', name: 'Renamed'),
      ),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupDeleteEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'removes the group and keeps the others',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupDeleteEvent(groupId: 'ga')),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(groups: <ProfileGroup>[groupB]),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );
  });

  group('ProfileGroupMoveProfilesEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'moves profiles between groups',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupMoveProfilesEvent(
          profileIds: <String>['p1', 'p3'],
          groupId: 'gb',
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileGroup(
                uuid: 'gb',
                name: 'B',
                profileIds: <String>['p3', 'p1'],
              ),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'a null groupId removes profiles from every group',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupMoveProfilesEvent(
          profileIds: <String>['p1', 'p3'],
          groupId: null,
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileGroup(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'ignores an unknown destination group',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupMoveProfilesEvent(
          profileIds: <String>['p1'],
          groupId: 'nope',
        ),
      ),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupRemoveProfilesEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'strips deleted profiles from all groups',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupRemoveProfilesEvent(<String>['p2', 'p3'])),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(uuid: 'ga', name: 'A', profileIds: <String>['p1']),
              ProfileGroup(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'does not persist when nothing referenced the profiles',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupRemoveProfilesEvent(<String>['zzz'])),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupSetSortByTypeEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'persists the toggle and keeps the groups',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupSetSortByTypeEvent(true)),
      expect: () => <ProfileGroupState>[
        ProfileGroupsLoaded(loadedData.copyWith(sortByType: true)),
      ],
      verify: (_) => expect(repo.puts.single.sortByType, isTrue),
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'is a no-op when the value is unchanged',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupSetSortByTypeEvent(false)),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  blocTest<ProfileGroupBloc, ProfileGroupState>(
    'keeps the optimistic state when the repository put throws',
    build: () {
      repo.throwOnPut = true;
      return bloc;
    },
    seed: () => const ProfileGroupsLoaded(loadedData),
    act: (ProfileGroupBloc bloc) =>
        bloc.add(const ProfileGroupDeleteEvent(groupId: 'gb')),
    expect: () => <ProfileGroupState>[
      const ProfileGroupsLoaded(
        ProfileGroupData(groups: <ProfileGroup>[groupA]),
      ),
    ],
  );
}
