import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';

class FakeProfileFolderRepository extends ProfileFolderRepository {
  ProfileFolderData? loadResult;
  bool throwOnLoad = false;
  bool throwOnPut = false;
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  /// Completes when the test says the local copy has caught up.
  Completer<bool> caughtUp = Completer<bool>();
  void Function(bool caughtUp)? onRound;

  /// Holds each put until the test completes it, when set.
  List<Completer<void>>? heldPuts;

  @override
  Future<ProfileFolderData?> getProfileFolders() async {
    if (throwOnLoad) throw Exception('load failed');
    return loadResult;
  }

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    puts.add(data);
    final List<Completer<void>>? held = heldPuts;
    if (held != null) {
      final Completer<void> release = Completer<void>();
      held.add(release);
      await release.future;
    }
    if (throwOnPut) throw Exception('put failed');
    return true;
  }

  @override
  Future<bool> waitForSync({Duration timeout = const Duration(seconds: 30)}) =>
      caughtUp.future;

  @override
  void watchSync(void Function(bool caughtUp) onRound) =>
      this.onRound = onRound;

  @override
  void stopWatching() => onRound = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ProfileFolder folderA = ProfileFolder(
    uuid: 'ga',
    name: 'A',
    profileIds: <String>['p1', 'p2'],
  );
  const ProfileFolder folderB = ProfileFolder(
    uuid: 'gb',
    name: 'B',
    profileIds: <String>['p3'],
  );
  const ProfileFolderData loadedData = ProfileFolderData(
    folders: <ProfileFolder>[folderA, folderB],
  );
  const ProfileFolderData dataWithUnfiled = ProfileFolderData(
    folders: <ProfileFolder>[folderA, folderB],
    unfiled: <String>['p4', 'p5'],
  );
  const ProfileFolderData dataWithSingleUnfiled = ProfileFolderData(
    folders: <ProfileFolder>[folderA, folderB],
    unfiled: <String>['p4'],
  );

  late FakeProfileFolderRepository repo;
  late ProfileFolderBloc bloc;

  setUp(() {
    repo = FakeProfileFolderRepository();
    bloc = ProfileFolderBloc(repo);
  });

  tearDown(() => bloc.close());

  test('initial state is ProfileFoldersInitial', () {
    expect(bloc.state, const ProfileFoldersInitial());
  });

  test('clearAll resets to initial', () {
    bloc.emit(const ProfileFoldersLoaded(loadedData));
    bloc.clearAll();
    expect(bloc.state, const ProfileFoldersInitial());
  });

  group('ProfileFolderLoadEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'shows the local copy before sync has caught up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) => bloc.add(const ProfileFolderLoadEvent()),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
      ],
      verify: (ProfileFolderBloc bloc) => expect(bloc.state.editable, isFalse),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'ignores edits until sync has caught up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) => bloc
        ..add(const ProfileFolderLoadEvent())
        ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z')),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
      ],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      're-reads and allows edits once sync has caught up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await Future<void>.delayed(Duration.zero);
        repo.loadResult = dataWithUnfiled;
        repo.caughtUp.complete(true);
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(dataWithUnfiled),
        ProfileFoldersLoaded(
          dataWithUnfiled.copyWith(
            folders: <ProfileFolder>[
              folderA.copyWith(name: 'Z'),
              folderB,
            ],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts, hasLength(1)),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'stays read-only after a sync timeout until a round catches up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await Future<void>.delayed(Duration.zero);
        repo.caughtUp.complete(false);
        repo.onRound!(false);
        await Future<void>.delayed(Duration.zero);
        expect(bloc.state.editable, isFalse);
        repo.onRound!(true);
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      "a sign-out drops the old session's sync callbacks",
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await Future<void>.delayed(Duration.zero);
        final Completer<bool> oldSession = repo.caughtUp;
        bloc.clearAll();
        repo.caughtUp = Completer<bool>();
        bloc.add(const ProfileFolderLoadEvent());
        await Future<void>.delayed(Duration.zero);
        oldSession.complete(true);
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersInitial(),
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'emits failed load when repository returns null',
      build: () => bloc,
      act: (ProfileFolderBloc bloc) => bloc.add(const ProfileFolderLoadEvent()),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersFailedLoad(),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'emits failed load when repository throws',
      build: () {
        repo.throwOnLoad = true;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) => bloc.add(const ProfileFolderLoadEvent()),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersFailedLoad(),
      ],
    );
  });

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'two quick changes are saved in the order they were made',
    build: () {
      repo.heldPuts = <Completer<void>>[];
      return bloc;
    },
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) async {
      bloc
        ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'First'))
        ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Second'));
      await Future<void>.delayed(Duration.zero);
      // The second change waits for the first save to finish.
      expect(repo.puts, hasLength(1));
      repo.heldPuts!.first.complete();
      await Future<void>.delayed(Duration.zero);
      repo.heldPuts!.last.complete();
    },
    verify: (ProfileFolderBloc bloc) {
      expect(
        repo.puts.map((ProfileFolderData d) => d.folders.first.name),
        <String>['First', 'Second'],
      );
      expect((bloc.state as ProfileFoldersLoaded).folders.first.name, 'Second');
    },
  );

  group('ProfileFolderCreateEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'appends a new folder and claims the given profiles from other folders',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderCreateEvent(
          uuid: 'gc',
          name: 'C',
          profileIds: <String>['p2', 'p4', 'p4'],
        ),
      ),
      verify: (ProfileFolderBloc bloc) {
        final ProfileFoldersLoaded state = bloc.state as ProfileFoldersLoaded;
        expect(state.folders.length, 3);
        expect(state.folders[0].profileIds, <String>['p1']);
        expect(state.folders[1], folderB);
        final ProfileFolder created = state.folders[2];
        expect(created.name, 'C');
        expect(created.uuid, 'gc');
        expect(created.profileIds, <String>['p2', 'p4']);
        expect(repo.puts.single, state.data);
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'is ignored when not loaded',
      build: () => bloc,
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderCreateEvent(uuid: 'gc', name: 'C')),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'claiming an unfiled profile strips it from unfiled, leaving '
      'the rest',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(dataWithUnfiled),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderCreateEvent(
          uuid: 'gc',
          name: 'C',
          profileIds: <String>['p4'],
        ),
      ),
      verify: (ProfileFolderBloc bloc) {
        final ProfileFoldersLoaded state = bloc.state as ProfileFoldersLoaded;
        expect(state.data.folders[0], folderA);
        expect(state.data.folders[1], folderB);
        expect(state.data.folders[2].profileIds, <String>['p4']);
        expect(state.data.unfiled, <String>['p5']);
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'a second create with the same uuid is ignored',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc
        ..add(
          const ProfileFolderCreateEvent(
            uuid: 'gc',
            name: 'C',
            profileIds: <String>['p4'],
          ),
        )
        ..add(
          const ProfileFolderCreateEvent(
            uuid: 'gc',
            name: 'C',
            profileIds: <String>['p4'],
          ),
        ),
      verify: (ProfileFolderBloc bloc) {
        final ProfileFoldersLoaded state = bloc.state as ProfileFoldersLoaded;
        expect(state.folders.map((ProfileFolder f) => f.uuid), <String>[
          folderA.uuid,
          folderB.uuid,
          'gc',
        ]);
        expect(repo.puts, hasLength(1));
      },
    );
  });

  group('ProfileFolderRenameEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'renames the matching folder only',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderRenameEvent(folderId: 'gb', name: 'Renamed'),
      ),
      expect: () => <ProfileFolderState>[
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              folderA,
              folderB.copyWith(name: 'Renamed'),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'does nothing for an unknown folder',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderRenameEvent(folderId: 'nope', name: 'Renamed'),
      ),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'renaming to the same name is a no-op (the _save unchanged guard)',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'A')),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileFolderDeleteEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'removes the folder, keeps the others, and puts its connections after '
      'everything unfiled shows, in folder order',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderDeleteEvent(
          folderId: 'ga',
          // 'x' is unfiled and was never dragged, so it is not stored yet.
          visibleUnfiled: <String>['x'],
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[folderB],
            unfiled: <String>['x', 'p1', 'p2'],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );
  });

  group('ProfileFolderMoveProfilesEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'moves profiles between folders',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>['p1', 'p3'],
          folderId: 'gb',
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileFolder(
                uuid: 'gb',
                name: 'B',
                profileIds: <String>['p3', 'p1'],
              ),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'a null folderId moves profiles out of every folder, after everything '
      'unfiled shows',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>['p1', 'p3'],
          folderId: null,
          visibleUnfiled: <String>['x'],
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileFolder(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
            unfiled: <String>['x', 'p1', 'p3'],
          ),
        ),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'ignores an unknown destination folder',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>['p1'],
          folderId: 'nope',
        ),
      ),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'moving an unfiled profile into a folder strips it from unfiled',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(dataWithSingleUnfiled),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderMoveProfilesEvent(
          profileIds: <String>['p4'],
          folderId: 'gb',
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              folderA,
              ProfileFolder(
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

  group('ProfileFolderRemoveProfilesEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'strips deleted profiles from all folders',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderRemoveProfilesEvent(<String>['p2', 'p3']),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(uuid: 'ga', name: 'A', profileIds: <String>['p1']),
              ProfileFolder(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
          ),
        ),
      ],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'does not persist when nothing referenced the profiles',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderRemoveProfilesEvent(<String>['zzz'])),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'strips a deleted profile that was only in unfiled',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(dataWithSingleUnfiled),
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderRemoveProfilesEvent(<String>['p4'])),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(loadedData),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );
  });

  group('ProfileFolderPlaceProfilesEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'drops a connection into another folder at the shown position',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderPlaceProfilesEvent(
          profileIds: <String>['p1'],
          folderId: 'gb',
          sectionOrder: <String>['p3', 'p1'],
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              ProfileFolder(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
              ProfileFolder(
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

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'drops a connection into unfiled at the shown position',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(dataWithSingleUnfiled),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderPlaceProfilesEvent(
          profileIds: <String>['p3'],
          folderId: null,
          sectionOrder: <String>['p4', 'p3'],
        ),
      ),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              folderA,
              ProfileFolder(uuid: 'gb', name: 'B', profileIds: <String>[]),
            ],
            unfiled: <String>['p4', 'p3'],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'a drop that changes nothing emits nothing and puts nothing',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderPlaceProfilesEvent(
          profileIds: <String>['p1'],
          folderId: 'ga',
          sectionOrder: <String>['p1', 'p2'],
        ),
      ),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'an unknown folderId is a no-op',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderPlaceProfilesEvent(
          profileIds: <String>['p1'],
          folderId: 'nope',
          sectionOrder: <String>['p1'],
        ),
      ),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('ProfileFolderReorderEvent', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'persists the new folder order',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderReorderEvent(<String>['gb', 'ga'])),
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[folderB, folderA]),
        ),
      ],
      verify: (_) => expect(repo.puts.length, 1),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'an unchanged order is a no-op',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) =>
          bloc.add(const ProfileFolderReorderEvent(<String>['ga', 'gb'])),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'a null folderId without the visible order only strips folders and '
    'leaves the stored unfiled order alone',
    build: () => bloc,
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) => bloc.add(
      const ProfileFolderMoveProfilesEvent(
        profileIds: <String>['p1'],
        folderId: null,
      ),
    ),
    expect: () => <ProfileFolderState>[
      const ProfileFoldersLoaded(
        ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(uuid: 'ga', name: 'A', profileIds: <String>['p2']),
            folderB,
          ],
        ),
      ),
    ],
  );

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'a failed save is sent again when the same action is repeated',
    build: () => bloc,
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) async {
      repo.throwOnPut = true;
      bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Renamed'));
      await Future<void>.delayed(Duration.zero);
      repo.throwOnPut = false;
      // Same data as the state already shows, but the atServer never got it.
      bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Renamed'));
    },
    verify: (_) {
      expect(repo.puts, hasLength(2));
      expect(repo.puts.last.folderById('ga')?.name, 'Renamed');
    },
  );

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'keeps the optimistic state when the repository put throws',
    build: () {
      repo.throwOnPut = true;
      return bloc;
    },
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) =>
        bloc.add(const ProfileFolderDeleteEvent(folderId: 'gb')),
    expect: () => <ProfileFolderState>[
      const ProfileFoldersLoaded(
        ProfileFolderData(folders: <ProfileFolder>[folderA]),
      ),
    ],
  );
}
