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
  const ProfileGroupData dataWithUngrouped = ProfileGroupData(
    groups: <ProfileGroup>[groupA, groupB],
    ungrouped: <String>['p4', 'p5'],
  );
  const ProfileGroupData dataWithSingleUngrouped = ProfileGroupData(
    groups: <ProfileGroup>[groupA, groupB],
    ungrouped: <String>['p4'],
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

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'claiming an ungrouped profile strips it from ungrouped, leaving '
      'the rest',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(dataWithUngrouped),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupCreateEvent(name: 'C', profileIds: <String>['p4']),
      ),
      verify: (ProfileGroupBloc bloc) {
        final ProfileGroupsLoaded state = bloc.state as ProfileGroupsLoaded;
        expect(state.data.groups[0], groupA);
        expect(state.data.groups[1], groupB);
        expect(state.data.groups[2].profileIds, <String>['p4']);
        expect(state.data.ungrouped, <String>['p5']);
      },
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

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'renaming to the same name is a no-op (the _save unchanged guard)',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupRenameEvent(groupId: 'ga', name: 'A')),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupDeleteEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'removes the group, keeps the others, and puts its connections after '
      'everything ungrouped shows, in folder order',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupDeleteEvent(
          groupId: 'ga',
          // 'x' is ungrouped and was never dragged, so it is not stored yet.
          visibleUngrouped: <String>['x'],
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[groupB],
            ungrouped: <String>['x', 'p1', 'p2'],
          ),
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
      'a null groupId moves profiles out of every folder, after everything '
      'ungrouped shows',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupMoveProfilesEvent(
          profileIds: <String>['p1', 'p3'],
          groupId: null,
          visibleUngrouped: <String>['x'],
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              ProfileGroup(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileGroup(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
            ungrouped: <String>['x', 'p1', 'p3'],
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

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'moving an ungrouped profile into a folder strips it from ungrouped',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(dataWithSingleUngrouped),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupMoveProfilesEvent(
          profileIds: <String>['p4'],
          groupId: 'gb',
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              groupA,
              ProfileGroup(
                uuid: 'gb',
                name: 'B',
                profileIds: <String>['p3', 'p4'],
              ),
            ],
          ),
        ),
      ],
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

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'strips a deleted profile that was only in ungrouped',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(dataWithSingleUngrouped),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupRemoveProfilesEvent(<String>['p4'])),
      expect: () => <ProfileGroupState>[const ProfileGroupsLoaded(loadedData)],
      verify: (_) => expect(repo.puts.length, 1),
    );
  });

  group('ProfileGroupPlaceProfilesEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'drops a connection into another folder at the shown position',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupPlaceProfilesEvent(
          profileIds: <String>['p1'],
          groupId: 'gb',
          sectionOrder: <String>['p3', 'p1'],
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
      verify: (_) => expect(repo.puts.length, 1),
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'drops a connection into ungrouped at the shown position',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(dataWithSingleUngrouped),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupPlaceProfilesEvent(
          profileIds: <String>['p3'],
          groupId: null,
          sectionOrder: <String>['p4', 'p3'],
        ),
      ),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(
            groups: <ProfileGroup>[
              groupA,
              ProfileGroup(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
            ungrouped: <String>['p4', 'p3'],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'a drop that changes nothing emits nothing and puts nothing',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupPlaceProfilesEvent(
          profileIds: <String>['p1'],
          groupId: 'ga',
          sectionOrder: <String>['p1', 'p2'],
        ),
      ),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'an unknown groupId is a no-op',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) => bloc.add(
        const ProfileGroupPlaceProfilesEvent(
          profileIds: <String>['p1'],
          groupId: 'nope',
          sectionOrder: <String>['p1'],
        ),
      ),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileGroupReorderFoldersEvent', () {
    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'persists the new folder order',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupReorderFoldersEvent(<String>['gb', 'ga'])),
      expect: () => <ProfileGroupState>[
        const ProfileGroupsLoaded(
          ProfileGroupData(groups: <ProfileGroup>[groupB, groupA]),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );

    blocTest<ProfileGroupBloc, ProfileGroupState>(
      'an unchanged order is a no-op',
      build: () => bloc,
      seed: () => const ProfileGroupsLoaded(loadedData),
      act: (ProfileGroupBloc bloc) =>
          bloc.add(const ProfileGroupReorderFoldersEvent(<String>['ga', 'gb'])),
      expect: () => <ProfileGroupState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  blocTest<ProfileGroupBloc, ProfileGroupState>(
    'a null groupId without the visible order only strips folders and '
    'leaves the stored ungrouped order alone',
    build: () => bloc,
    seed: () => const ProfileGroupsLoaded(loadedData),
    act: (ProfileGroupBloc bloc) => bloc.add(
      const ProfileGroupMoveProfilesEvent(
        profileIds: <String>['p1'],
        groupId: null,
      ),
    ),
    expect: () => <ProfileGroupState>[
      const ProfileGroupsLoaded(
        ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
            groupB,
          ],
        ),
      ),
    ],
  );

  blocTest<ProfileGroupBloc, ProfileGroupState>(
    'a failed save is sent again when the same action is repeated',
    build: () => bloc,
    seed: () => const ProfileGroupsLoaded(loadedData),
    act: (ProfileGroupBloc bloc) async {
      repo.throwOnPut = true;
      bloc.add(const ProfileGroupRenameEvent(groupId: 'ga', name: 'Renamed'));
      await Future<void>.delayed(Duration.zero);
      repo.throwOnPut = false;
      // Same data as the state already shows, but the atServer never got it.
      bloc.add(const ProfileGroupRenameEvent(groupId: 'ga', name: 'Renamed'));
    },
    verify: (_) {
      expect(repo.puts, hasLength(2));
      expect(repo.puts.last.groupById('ga')?.name, 'Renamed');
    },
  );

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
