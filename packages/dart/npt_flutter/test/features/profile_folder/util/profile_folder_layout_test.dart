import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';

void main() {
  const String unfiledTitle = 'Unfiled';

  Key headerKey(String id) =>
      ValueKey<String>('ProfileFolderSectionHeader-$id');
  Key rowKey(String uuid) => ValueKey<String>('ProfileListRow-$uuid');

  ProfileFolderLayout build({
    required ProfileFolderData data,
    required List<String> loaded,
    Set<String> collapsed = const <String>{},
  }) => ProfileFolderLayout.build(
    data: data,
    loaded: loaded,
    collapsed: collapsed,
    unfiledTitle: unfiledTitle,
  );

  group('ProfileFolderLayout.build', () {
    test('flat mode with no folders: no headers, one unfiled section', () {
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(),
        loaded: const <String>['a', 'b', 'c'],
      );

      expect(layout.showHeaders, isFalse);
      expect(layout.sections, hasLength(1));
      expect(layout.sections.single.id, ProfileFolderLayout.unfiledSectionId);
      expect(layout.entries, everyElement(isA<ProfileListRowEntry>()));
      expect(
        layout.entries.map(
          (ProfileListEntry e) => (e as ProfileListRowEntry).uuid,
        ),
        <String>['a', 'b', 'c'],
      );
    });

    test('folders are followed by an always-present unfiled section, even '
        'when it is empty', () {
      const ProfileFolder g1 = ProfileFolder(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a'],
      );
      const ProfileFolder g2 = ProfileFolder(
        uuid: 'g2',
        name: 'Desktops',
        profileIds: <String>['b'],
      );
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(folders: <ProfileFolder>[g1, g2]),
        loaded: const <String>['a', 'b'],
      );

      expect(layout.showHeaders, isTrue);
      expect(layout.sections, hasLength(3));
      expect(layout.sections.last.id, ProfileFolderLayout.unfiledSectionId);
      expect(layout.sections.last.uuids, isEmpty);
      expect(
        layout.entries.last.key,
        headerKey(ProfileFolderLayout.unfiledSectionId),
      );
      expect(layout.entries, hasLength(5)); // 3 headers + 2 rows
    });

    test('a collapsed section contributes only its header', () {
      const ProfileFolder g1 = ProfileFolder(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a', 'b'],
      );
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(folders: <ProfileFolder>[g1]),
        loaded: const <String>['a', 'b', 'c'],
        collapsed: const <String>{'g1'},
      );

      expect(layout.entries.map((ProfileListEntry e) => e.key), <Key>[
        headerKey('g1'),
        headerKey(ProfileFolderLayout.unfiledSectionId),
        rowKey('c'),
      ]);
    });

    test('ids that are not in the loaded list are hidden', () {
      const ProfileFolder g1 = ProfileFolder(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a', 'not-loaded', 'b'],
      );
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(folders: <ProfileFolder>[g1]),
        loaded: const <String>['a', 'b'],
      );

      expect(layout.sections.first.uuids, <String>['a', 'b']);
      expect(
        layout.entries.whereType<ProfileListRowEntry>().map(
          (ProfileListRowEntry e) => e.uuid,
        ),
        <String>['a', 'b'],
      );
    });

    test('entry keys identify headers and rows', () {
      const ProfileFolder g1 = ProfileFolder(
        uuid: 'folder-1',
        name: 'Servers',
        profileIds: <String>['uuid-a'],
      );
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(folders: <ProfileFolder>[g1]),
        loaded: const <String>['uuid-a'],
      );

      expect(
        layout.entries[0].key,
        const ValueKey<String>('ProfileFolderSectionHeader-folder-1'),
      );
      expect(
        layout.entries[1].key,
        const ValueKey<String>('ProfileListRow-uuid-a'),
      );
      expect(
        layout.entries[2].key,
        const ValueKey<String>(
          'ProfileFolderSectionHeader-${ProfileFolderLayout.unfiledSectionId}',
        ),
      );
    });
  });

  group('ProfileFolderLayout.resolveDrop', () {
    // entries: 0 header(g1) 3 header(g2) 5 header(g3) 6 header(unfiled)
    //          1 row(a)     4 row(c)                  7 row(d)
    //          2 row(b)
    const ProfileFolder g1 = ProfileFolder(
      uuid: 'g1',
      name: 'Servers',
      profileIds: <String>['a', 'b'],
    );
    const ProfileFolder g2 = ProfileFolder(
      uuid: 'g2',
      name: 'Desktops',
      profileIds: <String>['c'],
    );
    const ProfileFolder g3 = ProfileFolder(
      uuid: 'g3',
      name: 'Empty',
      profileIds: <String>[],
    );
    const ProfileFolderData data = ProfileFolderData(
      folders: <ProfileFolder>[g1, g2, g3],
    );
    const List<String> loaded = <String>['a', 'b', 'c', 'd'];

    ProfileFolderLayout fixtureLayout({
      Set<String> collapsed = const <String>{},
    }) => build(data: data, loaded: loaded, collapsed: collapsed);

    test('reorder within a folder', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 2, // row(b)
        newIndex: 1, // just above row(a), still inside Servers
      );

      expect(event, isA<ProfileFolderPlaceProfilesEvent>());
      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['b']);
      expect(placeEvent.folderId, 'g1');
      expect(placeEvent.sectionOrder, <String>['b', 'a']);

      final ProfileFolderData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        folderId: placeEvent.folderId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.folderById('g1')!.profileIds, <String>['b', 'a']);
      expect(result.folderById('g2')!.profileIds, <String>['c']);
    });

    test(
      'a row dropped just under another folder\'s header goes to its top',
      () {
        final ProfileFolderLayout layout = fixtureLayout();

        final ProfileFolderEvent? event = layout.resolveDrop(
          oldIndex: 4, // row(c), in Desktops
          newIndex: 1, // just under Servers' header
        );

        final ProfileFolderPlaceProfilesEvent placeEvent =
            event as ProfileFolderPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['c']);
        expect(placeEvent.folderId, 'g1');
        expect(placeEvent.sectionOrder, <String>['c', 'a', 'b']);

        final ProfileFolderData result = data.placeProfiles(
          profileIds: placeEvent.profileIds,
          folderId: placeEvent.folderId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.folderById('g1')!.profileIds, <String>['c', 'a', 'b']);
        expect(result.folderById('g2')!.profileIds, isEmpty);
      },
    );

    test(
      'a row dropped under a collapsed header goes to the end, and the '
      'sectionOrder (and the merged result) keep hidden members in place',
      () {
        // 'h1' is stored in the folder but not loaded, so it never appears
        // in the layout, yet must keep its position relative to 'a'.
        const ProfileFolder folder = ProfileFolder(
          uuid: 'g1',
          name: 'Servers',
          profileIds: <String>['h1', 'a', 'b'],
        );
        const ProfileFolderData localData = ProfileFolderData(
          folders: <ProfileFolder>[folder],
        );
        const List<String> localLoaded = <String>['a', 'b', 'c'];
        const Set<String> collapsed = <String>{'g1'};
        final ProfileFolderLayout layout = build(
          data: localData,
          loaded: localLoaded,
          collapsed: collapsed,
        );
        // entries: 0 header(g1) [collapsed] 1 header(unfiled) 2 row(c)

        final ProfileFolderEvent? event = layout.resolveDrop(
          oldIndex: 2, // row(c), unfiled
          newIndex: 1, // just under the collapsed Servers header
        );

        final ProfileFolderPlaceProfilesEvent placeEvent =
            event as ProfileFolderPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['c']);
        expect(placeEvent.folderId, 'g1');
        expect(placeEvent.sectionOrder, <String>['a', 'b', 'c']);

        final ProfileFolderData result = localData.placeProfiles(
          profileIds: placeEvent.profileIds,
          folderId: placeEvent.folderId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.folderById('g1')!.profileIds, <String>[
          'h1',
          'a',
          'b',
          'c',
        ]);
      },
    );

    test('a row dropped into an empty folder', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 4, // row(c), in Desktops
        newIndex: 5, // just under the empty folder's header
      );

      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['c']);
      expect(placeEvent.folderId, 'g3');
      expect(placeEvent.sectionOrder, <String>['c']);

      final ProfileFolderData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        folderId: placeEvent.folderId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.folderById('g3')!.profileIds, <String>['c']);
      expect(result.folderById('g2')!.profileIds, isEmpty);
    });

    test(
      'a row dropped above the first header goes to the top of the first section',
      () {
        final ProfileFolderLayout layout = fixtureLayout();

        final ProfileFolderEvent? event = layout.resolveDrop(
          oldIndex: 7, // row(d), unfiled
          newIndex: 0, // above everything
        );

        final ProfileFolderPlaceProfilesEvent placeEvent =
            event as ProfileFolderPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['d']);
        expect(placeEvent.folderId, 'g1');
        expect(placeEvent.sectionOrder, <String>['d', 'a', 'b']);

        final ProfileFolderData result = data.placeProfiles(
          profileIds: placeEvent.profileIds,
          folderId: placeEvent.folderId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.folderById('g1')!.profileIds, <String>['d', 'a', 'b']);
        expect(result.resolveUnfiled(loaded), isNot(contains('d')));
      },
    );

    test('a row dropped under the Unfiled header has a null folderId', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 1, // row(a), in Servers
        newIndex: 6, // just under the Unfiled header, above row(d)
      );

      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a']);
      expect(placeEvent.folderId, isNull);
      expect(placeEvent.sectionOrder, <String>['a', 'd']);

      final ProfileFolderData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        folderId: placeEvent.folderId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.folderById('g1')!.profileIds, <String>['b']);
      expect(result.unfiled, <String>['a', 'd']);
    });

    test('flat-mode reorder produces the full order', () {
      final ProfileFolderLayout layout = build(
        data: const ProfileFolderData(),
        loaded: const <String>['a', 'b', 'c'],
      );

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 0, // row(a)
        newIndex: 2, // to the end
      );

      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a']);
      expect(placeEvent.folderId, isNull);
      expect(placeEvent.sectionOrder, <String>['b', 'c', 'a']);

      final ProfileFolderData result = const ProfileFolderData().placeProfiles(
        profileIds: placeEvent.profileIds,
        folderId: placeEvent.folderId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.unfiled, <String>['b', 'c', 'a']);
    });

    test('a travelling selection is placed together where the dragged row '
        'lands, including selected ids from another, collapsed section', () {
      const Set<String> collapsed = <String>{'g2'};
      final ProfileFolderLayout layout = fixtureLayout(collapsed: collapsed);
      // entries with g2 collapsed: 0 header(g1) 1 row(a) 2 row(b)
      //   3 header(g2)[collapsed] 4 header(g3) 5 header(unfiled) 6 row(d)

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 1, // row(a), dragged
        newIndex: 5, // just under the Unfiled header, above row(d)
        movedIds: const <String>['a', 'c'], // 'c' lives in collapsed g2
      );

      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a', 'c']);
      expect(placeEvent.folderId, isNull);
      expect(placeEvent.sectionOrder, <String>['a', 'c', 'd']);

      final ProfileFolderData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        folderId: placeEvent.folderId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.folderById('g1')!.profileIds, <String>['b']);
      expect(result.folderById('g2')!.profileIds, isEmpty);
      expect(result.unfiled, <String>['a', 'c', 'd']);
    });

    test('a dragged row not present in movedIds moves alone', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 4, // row(c)
        newIndex: 1, // just under Servers' header
        movedIds: const <String>['a', 'd'], // does not include 'c'
      );

      final ProfileFolderPlaceProfilesEvent placeEvent =
          event as ProfileFolderPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['c']);
      expect(placeEvent.sectionOrder, <String>['c', 'a', 'b']);
    });

    test('a folder header reordered among the folders', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 3, // header(g2)
        newIndex: 0, // before header(g1)
      );

      expect(event, isA<ProfileFolderReorderEvent>());
      final ProfileFolderReorderEvent reorderEvent =
          event as ProfileFolderReorderEvent;
      expect(reorderEvent.folderIds, <String>['g2', 'g1', 'g3']);

      final ProfileFolderData result = data.withFoldersOrdered(
        reorderEvent.folderIds,
      );
      expect(result.folders.map((ProfileFolder f) => f.uuid), <String>[
        'g2',
        'g1',
        'g3',
      ]);
    });

    test('a folder dropped below Unfiled becomes the last folder', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 0, // header(g1)
        newIndex: 6, // just under the Unfiled header
      );

      final ProfileFolderReorderEvent reorderEvent =
          event as ProfileFolderReorderEvent;
      expect(reorderEvent.folderIds, <String>['g2', 'g3', 'g1']);

      final ProfileFolderData result = data.withFoldersOrdered(
        reorderEvent.folderIds,
      );
      expect(result.folders.map((ProfileFolder f) => f.uuid), <String>[
        'g2',
        'g3',
        'g1',
      ]);
    });

    test('dragging the Unfiled header changes nothing', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 6, // header(unfiled)
        newIndex: 0,
      );

      expect(event, isNull);
    });

    test('an unchanged folder order returns null', () {
      final ProfileFolderLayout layout = fixtureLayout();

      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 0, // header(g1), dropped back in the same place
        newIndex: 0,
      );

      expect(event, isNull);
    });

    test('an out-of-range oldIndex returns null', () {
      final ProfileFolderLayout layout = fixtureLayout();

      expect(layout.resolveDrop(oldIndex: -1, newIndex: 0), isNull);
      expect(
        layout.resolveDrop(oldIndex: layout.entries.length, newIndex: 0),
        isNull,
      );
    });
  });

  group('ProfileFolderLayout.resolveDrop with stepFolders', () {
    // entries: 0 header(A) 1 row(a) 2 header(B) 3 row(b) 4 header(unfiled)
    final ProfileFolderLayout layout = ProfileFolderLayout.build(
      data: const ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(uuid: 'A', name: 'A', profileIds: <String>['a']),
          ProfileFolder(uuid: 'B', name: 'B', profileIds: <String>['b']),
        ],
      ),
      loaded: const <String>['a', 'b'],
      collapsed: const <String>{},
      unfiledTitle: 'Unfiled',
    );

    test('move up past a row steps the folder up one place', () {
      // The screen reader's "move up" on header B: (2, 1).
      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 2,
        newIndex: 1,
        stepFolders: true,
      );
      expect(event, const ProfileFolderReorderEvent(<String>['B', 'A']));
    });

    test('move down past a row steps the folder down one place', () {
      final ProfileFolderEvent? event = layout.resolveDrop(
        oldIndex: 0,
        newIndex: 1,
        stepFolders: true,
      );
      expect(event, const ProfileFolderReorderEvent(<String>['B', 'A']));
    });

    test('the same one-entry move from a drag changes nothing', () {
      expect(layout.resolveDrop(oldIndex: 2, newIndex: 1), isNull);
    });

    test('stepping the last folder down is a no-op', () {
      expect(
        layout.resolveDrop(oldIndex: 2, newIndex: 3, stepFolders: true),
        isNull,
      );
    });
  });
}
