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

  /// Reports a failed put whose write still lands, as a timed out put can.
  bool putLandsButFails = false;
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  Completer<bool> caughtUp = Completer<bool>();
  void Function(bool caughtUp)? onRound;
  int watchSyncCalls = 0;

  List<Completer<void>>? heldPuts;

  List<Completer<void>>? heldReads;

  @override
  Future<ProfileFolderData?> getProfileFolders() async {
    final List<Completer<void>>? held = heldReads;
    if (held != null) {
      final Completer<void> release = Completer<void>();
      held.add(release);
      await release.future;
    }
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
    if (putLandsButFails) {
      loadResult = data;
      return false;
    }
    return true;
  }

  @override
  Future<bool> waitForSync({Duration timeout = const Duration(seconds: 30)}) =>
      caughtUp.future;

  @override
  void watchSync(void Function(bool caughtUp) onRound) {
    watchSyncCalls++;
    this.onRound = onRound;
  }

  @override
  void stopWatching() => onRound = null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() => Future<void>.delayed(Duration.zero);

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
      'does not save an edit made before sync has caught up',
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
      "a sign-out while a refresh is still reading keeps the old atSign's "
      'folders away',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        repo.heldReads = <Completer<void>>[];
        repo.onRound!(true);
        await settle();
        expect(repo.heldReads, hasLength(1));
        bloc.clearAll();
        repo.heldReads!.single.complete();
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersInitial(),
      ],
      verify: (_) => expect(repo.puts, isEmpty),
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
      bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Renamed'));
    },
    verify: (_) {
      expect(repo.puts, hasLength(2));
      expect(repo.puts.last.folderById('ga')?.name, 'Renamed');
    },
  );

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    "keeps the edit shown when the put throws and the folders can't be read",
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

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'shows the stored folders again when the repository put throws',
    build: () {
      repo.throwOnPut = true;
      repo.loadResult = loadedData;
      return bloc;
    },
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) =>
        bloc.add(const ProfileFolderDeleteEvent(folderId: 'gb')),
    expect: () => <ProfileFolderState>[
      const ProfileFoldersLoaded(
        ProfileFolderData(folders: <ProfileFolder>[folderA]),
      ),
      const ProfileFoldersLoaded(loadedData),
    ],
  );

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'keeps the edit shown without an error when a failed put landed after all',
    build: () {
      repo.putLandsButFails = true;
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
    verify: (ProfileFolderBloc bloc) {
      expect(bloc.state.editable, isTrue);
      expect(repo.puts, hasLength(1));
    },
  );

  blocTest<ProfileFolderBloc, ProfileFolderState>(
    'a sign-out while a failing put is held shows nothing after it',
    build: () {
      repo.loadResult = loadedData;
      repo.throwOnPut = true;
      repo.heldPuts = <Completer<void>>[];
      return bloc;
    },
    seed: () => const ProfileFoldersLoaded(loadedData),
    act: (ProfileFolderBloc bloc) async {
      bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Renamed'));
      await Future<void>.delayed(Duration.zero);
      bloc.clearAll();
      repo.heldPuts!.single.complete();
      await Future<void>.delayed(Duration.zero);
    },
    expect: () => <Object>[
      isA<ProfileFoldersLoaded>(),
      const ProfileFoldersInitial(),
    ],
  );

  group('edits made before sync has caught up', () {
    final ProfileFolder renamedA = folderA.copyWith(name: 'Z');
    final ProfileFolderData afterRename = ProfileFolderData(
      folders: <ProfileFolder>[renamedA, folderB],
      unfiled: const <String>['p4', 'p5'],
    );
    final ProfileFolderData afterMove = ProfileFolderData(
      folders: <ProfileFolder>[
        renamedA.copyWith(profileIds: <String>['p2']),
        folderB.copyWith(profileIds: <String>['p3', 'p1']),
      ],
      unfiled: const <String>['p4', 'p5'],
    );
    final ProfileFolderData afterRemove = ProfileFolderData(
      folders: <ProfileFolder>[
        renamedA.copyWith(profileIds: <String>['p2']),
        folderB.copyWith(profileIds: <String>['p1']),
      ],
      unfiled: const <String>['p4', 'p5'],
    );
    final ProfileFolderData afterDelete = ProfileFolderData(
      folders: <ProfileFolder>[
        renamedA.copyWith(profileIds: <String>['p2']),
      ],
      unfiled: const <String>['p4', 'p5', 'p1'],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'are applied in the order they were made once it catches up, and '
      'nothing is saved before',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc
          ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'))
          ..add(
            const ProfileFolderMoveProfilesEvent(
              profileIds: <String>['p1'],
              folderId: 'gb',
            ),
          )
          ..add(const ProfileFolderRemoveProfilesEvent(<String>['p3']))
          ..add(
            const ProfileFolderDeleteEvent(
              folderId: 'gb',
              visibleUnfiled: <String>['p4', 'p5'],
            ),
          );
        await settle();
        expect(repo.puts, isEmpty);
        expect(
          bloc.state,
          const ProfileFoldersLoaded(loadedData, synced: false),
        );
        repo.loadResult = dataWithUnfiled;
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(dataWithUnfiled),
        ProfileFoldersLoaded(afterRename),
        ProfileFoldersLoaded(afterMove),
        ProfileFoldersLoaded(afterRemove),
        ProfileFoldersLoaded(afterDelete),
      ],
      verify: (_) => expect(repo.puts, <ProfileFolderData>[
        afterRename,
        afterMove,
        afterRemove,
        afterDelete,
      ]),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'are kept through a sync round that has not caught up, and applied '
      'once, on the round that has',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
        await settle();
        repo.onRound!(false);
        await settle();
        expect(bloc.state.editable, isFalse);
        expect(repo.puts, isEmpty);
        repo.onRound!(true);
        await settle();
        repo.loadResult = repo.puts.single;
        repo.onRound!(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[renamedA, folderB]),
        ),
      ],
      verify: (_) => expect(repo.puts, hasLength(1)),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'are kept when reading the folders after catching up fails, and applied '
      'on the next round',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
        await settle();
        repo.loadResult = null;
        repo.onRound!(true);
        await settle();
        expect(bloc.state.editable, isFalse);
        expect(repo.puts, isEmpty);
        repo.loadResult = loadedData;
        repo.onRound!(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[renamedA, folderB]),
        ),
      ],
      verify: (_) => expect(repo.puts, hasLength(1)),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'are applied by a round that has not caught up, when an earlier round '
      'that had caught up could not read the folders',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
        await settle();
        repo.loadResult = null;
        repo.onRound!(true);
        await settle();
        expect(bloc.state.editable, isFalse);
        expect(repo.puts, isEmpty);
        repo.loadResult = loadedData;
        repo.onRound!(false);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[renamedA, folderB]),
        ),
      ],
      verify: (ProfileFolderBloc bloc) {
        expect(bloc.state.editable, isTrue);
        expect(repo.puts, hasLength(1));
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'run before an event that was queued while the catch-up round was '
      'reading, so the later edit wins',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderMoveProfilesEvent(
            profileIds: <String>['p3'],
            folderId: 'ga',
          ),
        );
        await settle();
        expect(repo.puts, isEmpty);

        repo.loadResult = dataWithUnfiled;
        repo.heldReads = <Completer<void>>[];
        repo.onRound!(true);
        await settle();
        expect(repo.heldReads, hasLength(1));
        bloc.add(
          const ProfileFolderMoveProfilesEvent(
            profileIds: <String>['p3'],
            folderId: 'gb',
          ),
        );
        await settle();
        expect(repo.puts, isEmpty);
        repo.heldReads!.single.complete();
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(dataWithUnfiled),
        ProfileFoldersLoaded(
          dataWithUnfiled.copyWith(
            folders: <ProfileFolder>[
              folderA.copyWith(profileIds: <String>['p1', 'p2', 'p3']),
              folderB.copyWith(profileIds: <String>[]),
            ],
          ),
        ),
        const ProfileFoldersLoaded(dataWithUnfiled),
      ],
      verify: (ProfileFolderBloc bloc) {
        expect(repo.puts, hasLength(2));
        expect(repo.puts.last.folderById('gb')?.profileIds, <String>['p3']);
        expect(repo.puts.last.folderById('ga')?.profileIds, <String>[
          'p1',
          'p2',
        ]);
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'for a folder that sync removed are harmless, and the rest still apply',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc
          ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'))
          ..add(
            const ProfileFolderMoveProfilesEvent(
              profileIds: <String>['p3'],
              folderId: 'ga',
            ),
          )
          ..add(const ProfileFolderDeleteEvent(folderId: 'ga'))
          ..add(const ProfileFolderRenameEvent(folderId: 'gb', name: 'Y'));
        await settle();
        repo.loadResult = const ProfileFolderData(
          folders: <ProfileFolder>[folderB],
        );
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[folderB]),
        ),
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[folderB.copyWith(name: 'Y')],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts, hasLength(1)),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'made while nothing is loaded are not kept for later',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc
          ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'))
          ..add(const ProfileFolderLoadEvent());
        await settle();
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
      ],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('once the folders have synced', () {
    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'a later round that has not caught up keeps them editable',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        repo.caughtUp.complete(true);
        await settle();
        expect(bloc.state.editable, isTrue);

        repo.loadResult = dataWithUnfiled;
        repo.onRound!(false);
        await settle();
        expect(bloc.state.editable, isTrue);
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
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
  });

  group('collapsing a section before sync has caught up', () {
    final ProfileFolder collapsedA = folderA.copyWith(collapsed: true);
    final ProfileFolderData collapsedGa = ProfileFolderData(
      folders: <ProfileFolder>[collapsedA, folderB],
    );

    final ProfileFolderData serverWithCollapsedGa = ProfileFolderData(
      folders: <ProfileFolder>[collapsedA, folderB],
      unfiled: const <String>['p4', 'p5'],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'shows at once and saves nothing',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
        );
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(collapsedGa, synced: false),
      ],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'is kept when a refresh round has not caught up, and saved once on '
      'top of what the atServer sent when one does',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
        );
        await settle();
        repo.loadResult = dataWithUnfiled;
        repo.onRound!(false);
        await settle();
        expect(repo.puts, isEmpty);
        repo.onRound!(true);
        await settle();
        repo.loadResult = serverWithCollapsedGa;
        repo.onRound!(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(collapsedGa, synced: false),
        ProfileFoldersLoaded(serverWithCollapsedGa, synced: false),
        ProfileFoldersLoaded(serverWithCollapsedGa),
      ],
      verify: (_) =>
          expect(repo.puts, <ProfileFolderData>[serverWithCollapsedGa]),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'collapsing the unfiled section is saved when it catches up',
      build: () {
        repo.loadResult = dataWithUnfiled;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderSetCollapsedEvent(folderId: null, collapsed: true),
        );
        await settle();
        expect(repo.puts, isEmpty);
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(dataWithUnfiled, synced: false),
        ProfileFoldersLoaded(
          dataWithUnfiled.copyWith(unfiledCollapsed: true),
          synced: false,
        ),
        ProfileFoldersLoaded(dataWithUnfiled.copyWith(unfiledCollapsed: true)),
      ],
      verify: (_) => expect(repo.puts.single.unfiledCollapsed, isTrue),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'is saved before the edits made while waiting, which then build on it',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc
          ..add(
            const ProfileFolderSetCollapsedEvent(
              folderId: 'ga',
              collapsed: true,
            ),
          )
          ..add(const ProfileFolderRenameEvent(folderId: 'gb', name: 'Y'));
        await settle();
        expect(repo.puts, isEmpty);
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(collapsedGa, synced: false),
        ProfileFoldersLoaded(collapsedGa),
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              collapsedA,
              folderB.copyWith(name: 'Y'),
            ],
          ),
        ),
      ],
      verify: (_) => expect(repo.puts, hasLength(2)),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'toggled back to what the atServer holds saves nothing when it catches '
      'up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc
          ..add(
            const ProfileFolderSetCollapsedEvent(
              folderId: 'ga',
              collapsed: true,
            ),
          )
          ..add(
            const ProfileFolderSetCollapsedEvent(
              folderId: 'ga',
              collapsed: false,
            ),
          )
          ..add(
            const ProfileFolderSetCollapsedEvent(
              folderId: null,
              collapsed: true,
            ),
          )
          ..add(
            const ProfileFolderSetCollapsedEvent(
              folderId: null,
              collapsed: false,
            ),
          );
        await settle();
        expect(repo.puts, isEmpty);
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(collapsedGa, synced: false),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(
          loadedData.copyWith(unfiledCollapsed: true),
          synced: false,
        ),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
      ],
      verify: (ProfileFolderBloc bloc) {
        expect(repo.puts, isEmpty);
        expect(bloc.state.editable, isTrue);
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'for a folder the atServer data no longer has saves nothing when it '
      'catches up',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderSetCollapsedEvent(folderId: 'gb', collapsed: true),
        );
        await settle();
        expect(repo.puts, isEmpty);
        repo.loadResult = const ProfileFolderData(
          folders: <ProfileFolder>[folderA],
        );
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              folderA,
              folderB.copyWith(collapsed: true),
            ],
          ),
          synced: false,
        ),
        const ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[folderA]),
        ),
      ],
      verify: (ProfileFolderBloc bloc) {
        expect(repo.puts, isEmpty);
        expect(bloc.state.editable, isTrue);
      },
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'are not applied again by later rounds (collapse before sync, catch up, '
      'expand, another round: it stays expanded)',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        bloc.add(
          const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
        );
        await settle();
        repo.caughtUp.complete(true);
        await settle();
        expect(repo.puts, <ProfileFolderData>[collapsedGa]);

        bloc.add(
          const ProfileFolderSetCollapsedEvent(
            folderId: 'ga',
            collapsed: false,
          ),
        );
        await settle();
        expect(repo.puts, hasLength(2));

        repo.loadResult = dataWithUnfiled;
        repo.onRound!(false);
        await settle();
        repo.onRound!(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(collapsedGa, synced: false),
        ProfileFoldersLoaded(collapsedGa),
        const ProfileFoldersLoaded(loadedData),
        const ProfileFoldersLoaded(dataWithUnfiled),
      ],
      verify: (ProfileFolderBloc bloc) {
        expect(repo.puts, hasLength(2));
        expect(
          (bloc.state as ProfileFoldersLoaded).data.folderById('ga')?.collapsed,
          isFalse,
        );
      },
    );
  });

  group('ProfileFolderSetCollapsedEvent', () {
    final ProfileFolderData collapsedGa = ProfileFolderData(
      folders: <ProfileFolder>[folderA.copyWith(collapsed: true), folderB],
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'once caught up, saves the collapse at once',
      build: () => bloc,
      seed: () => const ProfileFoldersLoaded(loadedData),
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
      ),
      expect: () => <ProfileFolderState>[ProfileFoldersLoaded(collapsedGa)],
      verify: (_) => expect(repo.puts, <ProfileFolderData>[collapsedGa]),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'is ignored when nothing is loaded',
      build: () => bloc,
      act: (ProfileFolderBloc bloc) => bloc.add(
        const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
      ),
      expect: () => <ProfileFolderState>[],
      verify: (_) => expect(repo.puts, isEmpty),
    );
  });

  group('sign-out and reload', () {
    final ProfileFolder collapsedA = folderA.copyWith(collapsed: true);

    Future<void> editAndCollapseBeforeSync(ProfileFolderBloc bloc) async {
      bloc
        ..add(const ProfileFolderRenameEvent(folderId: 'gb', name: 'Y'))
        ..add(
          const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
        );
      await settle();
      expect(repo.puts, isEmpty);
    }

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'sign-out drops edits and collapses made before sync, so the next '
      'sign-in does not save them',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        await editAndCollapseBeforeSync(bloc);
        bloc.clearAll();
        repo.caughtUp = Completer<bool>();
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        repo.caughtUp.complete(true);
        await settle();
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[collapsedA, folderB]),
          synced: false,
        ),
        const ProfileFoldersInitial(),
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
      ],
      verify: (_) => expect(repo.puts, isEmpty),
    );

    blocTest<ProfileFolderBloc, ProfileFolderState>(
      'a new load drops edits and collapses made before sync, and later '
      'edits save without them',
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        await editAndCollapseBeforeSync(bloc);
        repo.caughtUp = Completer<bool>();
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        repo.caughtUp.complete(true);
        await settle();
        expect(repo.puts, isEmpty);
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[collapsedA, folderB]),
          synced: false,
        ),
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
        ProfileFoldersLoaded(
          ProfileFolderData(
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
      "a sign-out and new load during the catch-up save leave the old "
      "session's edits behind",
      build: () {
        repo.loadResult = loadedData;
        return bloc;
      },
      act: (ProfileFolderBloc bloc) async {
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        await editAndCollapseBeforeSync(bloc);
        repo.heldPuts = <Completer<void>>[];
        repo.onRound!(true);
        await settle();
        expect(repo.puts, hasLength(1));

        bloc.clearAll();
        repo.caughtUp = Completer<bool>();
        bloc.add(const ProfileFolderLoadEvent());
        await settle();
        repo.heldPuts!.single.complete();
        await settle();
        repo.caughtUp.complete(true);
        await settle();
        expect(repo.puts, hasLength(1));
        repo.heldPuts = null;
        bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
      },
      expect: () => <ProfileFolderState>[
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[collapsedA, folderB]),
          synced: false,
        ),
        ProfileFoldersLoaded(
          ProfileFolderData(folders: <ProfileFolder>[collapsedA, folderB]),
        ),
        const ProfileFoldersInitial(),
        const ProfileFoldersLoading(),
        const ProfileFoldersLoaded(loadedData, synced: false),
        const ProfileFoldersLoaded(loadedData),
        ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[
              folderA.copyWith(name: 'Z'),
              folderB,
            ],
          ),
        ),
      ],
      verify: (_) {
        expect(
          repo.puts,
          hasLength(2),
          reason:
              'only the save already in flight, not the queued rename of gb',
        );
        expect(repo.puts.first.folderById('gb')?.name, 'B');
        expect(repo.puts.last.folderById('gb')?.name, 'B');
        expect(repo.puts.last.folderById('ga')?.collapsed, isFalse);
      },
    );
  });

  group('closing the bloc', () {
    test('while a load waits behind a save, nothing throws and the sync '
        'listener is not attached again', () async {
      repo.loadResult = loadedData;
      repo.heldPuts = <Completer<void>>[];
      bloc.emit(const ProfileFoldersLoaded(loadedData));
      bloc.add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'));
      await settle();
      expect(repo.puts, hasLength(1));

      bloc.add(const ProfileFolderLoadEvent());
      final Future<void> closed = bloc.close();
      repo.heldPuts!.single.complete();
      await closed;
      await settle();

      expect(bloc.isClosed, isTrue);
      expect(repo.watchSyncCalls, 0);
      expect(repo.onRound, isNull);
    });

    test('sync callbacks that arrive after it is closed are ignored', () async {
      repo.loadResult = loadedData;
      bloc.add(const ProfileFolderLoadEvent());
      await settle();
      final void Function(bool caughtUp) onRound = repo.onRound!;
      await bloc.close();

      onRound(true);
      repo.caughtUp.complete(true);
      await settle();

      expect(bloc.isClosed, isTrue);
      expect(repo.puts, isEmpty);
    });

    test('while the catch-up round saves a collapse, nothing throws and the '
        'edits made before sync are not replayed', () async {
      repo.loadResult = loadedData;
      repo.heldPuts = <Completer<void>>[];
      bloc.add(const ProfileFolderLoadEvent());
      await settle();
      bloc
        ..add(const ProfileFolderRenameEvent(folderId: 'gb', name: 'Y'))
        ..add(
          const ProfileFolderSetCollapsedEvent(folderId: 'ga', collapsed: true),
        );
      await settle();
      repo.onRound!(true);
      await settle();
      expect(repo.puts, hasLength(1));
      expect(repo.puts.single.folderById('ga')?.collapsed, isTrue);

      final Future<void> closed = bloc.close();
      repo.heldPuts!.single.complete();
      await closed;
      await settle();

      expect(bloc.isClosed, isTrue);
      expect(repo.puts, hasLength(1));
    });

    test('while the catch-up round saves a deferred edit, nothing throws and '
        'the edits after it are not replayed', () async {
      repo.loadResult = loadedData;
      repo.heldPuts = <Completer<void>>[];
      bloc.add(const ProfileFolderLoadEvent());
      await settle();
      bloc
        ..add(const ProfileFolderRenameEvent(folderId: 'gb', name: 'Y'))
        ..add(const ProfileFolderRenameEvent(folderId: 'ga', name: 'Z'))
        ..add(const ProfileFolderDeleteEvent(folderId: 'gb'));
      await settle();
      repo.onRound!(true);
      await settle();
      expect(repo.puts, hasLength(1));
      expect(repo.puts.single.folderById('gb')?.name, 'Y');

      final Future<void> closed = bloc.close();
      repo.heldPuts!.single.complete();
      await closed;
      await settle();

      expect(bloc.isClosed, isTrue);
      expect(repo.puts, hasLength(1));
    });

    test('while a load is still reading, the sync listener is not '
        'attached', () async {
      repo.loadResult = loadedData;
      repo.heldReads = <Completer<void>>[];
      bloc.add(const ProfileFolderLoadEvent());
      await settle();
      expect(repo.heldReads, hasLength(1));

      final Future<void> closed = bloc.close();
      repo.heldReads!.single.complete();
      await closed;
      await settle();

      expect(bloc.isClosed, isTrue);
      expect(bloc.state, const ProfileFoldersLoading());
      expect(repo.watchSyncCalls, 0);
      expect(repo.onRound, isNull);
    });
  });
}
