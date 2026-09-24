import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';

void main() {
  const String ungroupedTitle = 'Ungrouped';

  Key headerKey(String id) => ValueKey<String>('ProfileGroupSectionHeader-$id');
  Key rowKey(String uuid) => ValueKey<String>('ProfileListRow-$uuid');

  ProfileGroupLayout build({
    required ProfileGroupData data,
    required List<String> loaded,
    Set<String> collapsed = const <String>{},
  }) => ProfileGroupLayout.build(
    data: data,
    loaded: loaded,
    collapsed: collapsed,
    ungroupedTitle: ungroupedTitle,
  );

  group('ProfileGroupLayout.build', () {
    test('flat mode with no folders: no headers, one ungrouped section', () {
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(),
        loaded: const <String>['a', 'b', 'c'],
      );

      expect(layout.showHeaders, isFalse);
      expect(layout.sections, hasLength(1));
      expect(layout.sections.single.id, ProfileGroupLayout.ungroupedSectionId);
      expect(layout.entries, everyElement(isA<ProfileListRowEntry>()));
      expect(
        layout.entries.map(
          (ProfileListEntry e) => (e as ProfileListRowEntry).uuid,
        ),
        <String>['a', 'b', 'c'],
      );
    });

    test('folders are followed by an always-present ungrouped section, even '
        'when it is empty', () {
      const ProfileGroup g1 = ProfileGroup(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a'],
      );
      const ProfileGroup g2 = ProfileGroup(
        uuid: 'g2',
        name: 'Desktops',
        profileIds: <String>['b'],
      );
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(groups: <ProfileGroup>[g1, g2]),
        loaded: const <String>['a', 'b'],
      );

      expect(layout.showHeaders, isTrue);
      expect(layout.sections, hasLength(3));
      expect(layout.sections.last.id, ProfileGroupLayout.ungroupedSectionId);
      expect(layout.sections.last.uuids, isEmpty);
      expect(
        layout.entries.last.key,
        headerKey(ProfileGroupLayout.ungroupedSectionId),
      );
      expect(layout.entries, hasLength(5)); // 3 headers + 2 rows
    });

    test('a collapsed section contributes only its header', () {
      const ProfileGroup g1 = ProfileGroup(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a', 'b'],
      );
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(groups: <ProfileGroup>[g1]),
        loaded: const <String>['a', 'b', 'c'],
        collapsed: const <String>{'g1'},
      );

      expect(layout.entries.map((ProfileListEntry e) => e.key), <Key>[
        headerKey('g1'),
        headerKey(ProfileGroupLayout.ungroupedSectionId),
        rowKey('c'),
      ]);
    });

    test('ids that are not in the loaded list are hidden', () {
      const ProfileGroup g1 = ProfileGroup(
        uuid: 'g1',
        name: 'Servers',
        profileIds: <String>['a', 'not-loaded', 'b'],
      );
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(groups: <ProfileGroup>[g1]),
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
      const ProfileGroup g1 = ProfileGroup(
        uuid: 'folder-1',
        name: 'Servers',
        profileIds: <String>['uuid-a'],
      );
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(groups: <ProfileGroup>[g1]),
        loaded: const <String>['uuid-a'],
      );

      expect(
        layout.entries[0].key,
        const ValueKey<String>('ProfileGroupSectionHeader-folder-1'),
      );
      expect(
        layout.entries[1].key,
        const ValueKey<String>('ProfileListRow-uuid-a'),
      );
      expect(
        layout.entries[2].key,
        const ValueKey<String>(
          'ProfileGroupSectionHeader-${ProfileGroupLayout.ungroupedSectionId}',
        ),
      );
    });
  });

  group('ProfileGroupLayout.resolveDrop', () {
    // entries: 0 header(g1) 3 header(g2) 5 header(g3) 6 header(ungrouped)
    //          1 row(a)     4 row(c)                  7 row(d)
    //          2 row(b)
    const ProfileGroup g1 = ProfileGroup(
      uuid: 'g1',
      name: 'Servers',
      profileIds: <String>['a', 'b'],
    );
    const ProfileGroup g2 = ProfileGroup(
      uuid: 'g2',
      name: 'Desktops',
      profileIds: <String>['c'],
    );
    const ProfileGroup g3 = ProfileGroup(
      uuid: 'g3',
      name: 'Empty',
      profileIds: <String>[],
    );
    const ProfileGroupData data = ProfileGroupData(
      groups: <ProfileGroup>[g1, g2, g3],
    );
    const List<String> loaded = <String>['a', 'b', 'c', 'd'];

    ProfileGroupLayout fixtureLayout({
      Set<String> collapsed = const <String>{},
    }) => build(data: data, loaded: loaded, collapsed: collapsed);

    test('reorder within a folder', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 2, // row(b)
        newIndex: 1, // just above row(a), still inside Servers
      );

      expect(event, isA<ProfileGroupPlaceProfilesEvent>());
      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['b']);
      expect(placeEvent.groupId, 'g1');
      expect(placeEvent.sectionOrder, <String>['b', 'a']);

      final ProfileGroupData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        groupId: placeEvent.groupId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.groupById('g1')!.profileIds, <String>['b', 'a']);
      expect(result.groupById('g2')!.profileIds, <String>['c']);
    });

    test(
      'a row dropped just under another folder\'s header goes to its top',
      () {
        final ProfileGroupLayout layout = fixtureLayout();

        final ProfileGroupEvent? event = layout.resolveDrop(
          oldIndex: 4, // row(c), in Desktops
          newIndex: 1, // just under Servers' header
        );

        final ProfileGroupPlaceProfilesEvent placeEvent =
            event as ProfileGroupPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['c']);
        expect(placeEvent.groupId, 'g1');
        expect(placeEvent.sectionOrder, <String>['c', 'a', 'b']);

        final ProfileGroupData result = data.placeProfiles(
          profileIds: placeEvent.profileIds,
          groupId: placeEvent.groupId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.groupById('g1')!.profileIds, <String>['c', 'a', 'b']);
        expect(result.groupById('g2')!.profileIds, isEmpty);
      },
    );

    test(
      'a row dropped under a collapsed header goes to the end, and the '
      'sectionOrder (and the merged result) keep hidden members in place',
      () {
        // 'h1' is stored in the folder but not loaded, so it never appears
        // in the layout, yet must keep its position relative to 'a'.
        const ProfileGroup folder = ProfileGroup(
          uuid: 'g1',
          name: 'Servers',
          profileIds: <String>['h1', 'a', 'b'],
        );
        const ProfileGroupData localData = ProfileGroupData(
          groups: <ProfileGroup>[folder],
        );
        const List<String> localLoaded = <String>['a', 'b', 'c'];
        const Set<String> collapsed = <String>{'g1'};
        final ProfileGroupLayout layout = build(
          data: localData,
          loaded: localLoaded,
          collapsed: collapsed,
        );
        // entries: 0 header(g1) [collapsed] 1 header(ungrouped) 2 row(c)

        final ProfileGroupEvent? event = layout.resolveDrop(
          oldIndex: 2, // row(c), ungrouped
          newIndex: 1, // just under the collapsed Servers header
        );

        final ProfileGroupPlaceProfilesEvent placeEvent =
            event as ProfileGroupPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['c']);
        expect(placeEvent.groupId, 'g1');
        expect(placeEvent.sectionOrder, <String>['a', 'b', 'c']);

        final ProfileGroupData result = localData.placeProfiles(
          profileIds: placeEvent.profileIds,
          groupId: placeEvent.groupId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.groupById('g1')!.profileIds, <String>[
          'h1',
          'a',
          'b',
          'c',
        ]);
      },
    );

    test('a row dropped into an empty folder', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 4, // row(c), in Desktops
        newIndex: 5, // just under the empty folder's header
      );

      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['c']);
      expect(placeEvent.groupId, 'g3');
      expect(placeEvent.sectionOrder, <String>['c']);

      final ProfileGroupData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        groupId: placeEvent.groupId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.groupById('g3')!.profileIds, <String>['c']);
      expect(result.groupById('g2')!.profileIds, isEmpty);
    });

    test(
      'a row dropped above the first header goes to the top of the first section',
      () {
        final ProfileGroupLayout layout = fixtureLayout();

        final ProfileGroupEvent? event = layout.resolveDrop(
          oldIndex: 7, // row(d), ungrouped
          newIndex: 0, // above everything
        );

        final ProfileGroupPlaceProfilesEvent placeEvent =
            event as ProfileGroupPlaceProfilesEvent;
        expect(placeEvent.profileIds, <String>['d']);
        expect(placeEvent.groupId, 'g1');
        expect(placeEvent.sectionOrder, <String>['d', 'a', 'b']);

        final ProfileGroupData result = data.placeProfiles(
          profileIds: placeEvent.profileIds,
          groupId: placeEvent.groupId,
          sectionOrder: placeEvent.sectionOrder,
        );
        expect(result.groupById('g1')!.profileIds, <String>['d', 'a', 'b']);
        expect(result.resolveUngrouped(loaded), isNot(contains('d')));
      },
    );

    test('a row dropped under the Ungrouped header has a null groupId', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 1, // row(a), in Servers
        newIndex: 6, // just under the Ungrouped header, above row(d)
      );

      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a']);
      expect(placeEvent.groupId, isNull);
      expect(placeEvent.sectionOrder, <String>['a', 'd']);

      final ProfileGroupData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        groupId: placeEvent.groupId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.groupById('g1')!.profileIds, <String>['b']);
      expect(result.ungrouped, <String>['a', 'd']);
    });

    test('flat-mode reorder produces the full order', () {
      final ProfileGroupLayout layout = build(
        data: const ProfileGroupData(),
        loaded: const <String>['a', 'b', 'c'],
      );

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 0, // row(a)
        newIndex: 2, // to the end
      );

      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a']);
      expect(placeEvent.groupId, isNull);
      expect(placeEvent.sectionOrder, <String>['b', 'c', 'a']);

      final ProfileGroupData result = const ProfileGroupData().placeProfiles(
        profileIds: placeEvent.profileIds,
        groupId: placeEvent.groupId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.ungrouped, <String>['b', 'c', 'a']);
    });

    test('a travelling selection is placed together where the dragged row '
        'lands, including selected ids from another, collapsed section', () {
      const Set<String> collapsed = <String>{'g2'};
      final ProfileGroupLayout layout = fixtureLayout(collapsed: collapsed);
      // entries with g2 collapsed: 0 header(g1) 1 row(a) 2 row(b)
      //   3 header(g2)[collapsed] 4 header(g3) 5 header(ungrouped) 6 row(d)

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 1, // row(a), dragged
        newIndex: 5, // just under the Ungrouped header, above row(d)
        movedIds: const <String>['a', 'c'], // 'c' lives in collapsed g2
      );

      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['a', 'c']);
      expect(placeEvent.groupId, isNull);
      expect(placeEvent.sectionOrder, <String>['a', 'c', 'd']);

      final ProfileGroupData result = data.placeProfiles(
        profileIds: placeEvent.profileIds,
        groupId: placeEvent.groupId,
        sectionOrder: placeEvent.sectionOrder,
      );
      expect(result.groupById('g1')!.profileIds, <String>['b']);
      expect(result.groupById('g2')!.profileIds, isEmpty);
      expect(result.ungrouped, <String>['a', 'c', 'd']);
    });

    test('a dragged row not present in movedIds moves alone', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 4, // row(c)
        newIndex: 1, // just under Servers' header
        movedIds: const <String>['a', 'd'], // does not include 'c'
      );

      final ProfileGroupPlaceProfilesEvent placeEvent =
          event as ProfileGroupPlaceProfilesEvent;
      expect(placeEvent.profileIds, <String>['c']);
      expect(placeEvent.sectionOrder, <String>['c', 'a', 'b']);
    });

    test('a folder header reordered among the folders', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 3, // header(g2)
        newIndex: 0, // before header(g1)
      );

      expect(event, isA<ProfileGroupReorderFoldersEvent>());
      final ProfileGroupReorderFoldersEvent reorderEvent =
          event as ProfileGroupReorderFoldersEvent;
      expect(reorderEvent.groupIds, <String>['g2', 'g1', 'g3']);

      final ProfileGroupData result = data.withFoldersOrdered(
        reorderEvent.groupIds,
      );
      expect(result.groups.map((ProfileGroup g) => g.uuid), <String>[
        'g2',
        'g1',
        'g3',
      ]);
    });

    test('a folder dropped below Ungrouped becomes the last folder', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 0, // header(g1)
        newIndex: 6, // just under the Ungrouped header
      );

      final ProfileGroupReorderFoldersEvent reorderEvent =
          event as ProfileGroupReorderFoldersEvent;
      expect(reorderEvent.groupIds, <String>['g2', 'g3', 'g1']);

      final ProfileGroupData result = data.withFoldersOrdered(
        reorderEvent.groupIds,
      );
      expect(result.groups.map((ProfileGroup g) => g.uuid), <String>[
        'g2',
        'g3',
        'g1',
      ]);
    });

    test('dragging the Ungrouped header changes nothing', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 6, // header(ungrouped)
        newIndex: 0,
      );

      expect(event, isNull);
    });

    test('an unchanged folder order returns null', () {
      final ProfileGroupLayout layout = fixtureLayout();

      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 0, // header(g1), dropped back in the same place
        newIndex: 0,
      );

      expect(event, isNull);
    });

    test('an out-of-range oldIndex returns null', () {
      final ProfileGroupLayout layout = fixtureLayout();

      expect(layout.resolveDrop(oldIndex: -1, newIndex: 0), isNull);
      expect(
        layout.resolveDrop(oldIndex: layout.entries.length, newIndex: 0),
        isNull,
      );
    });
  });

  group('ProfileGroupLayout.resolveDrop with stepFolders', () {
    // entries: 0 header(A) 1 row(a) 2 header(B) 3 row(b) 4 header(ungrouped)
    final ProfileGroupLayout layout = ProfileGroupLayout.build(
      data: const ProfileGroupData(
        groups: <ProfileGroup>[
          ProfileGroup(uuid: 'A', name: 'A', profileIds: <String>['a']),
          ProfileGroup(uuid: 'B', name: 'B', profileIds: <String>['b']),
        ],
      ),
      loaded: const <String>['a', 'b'],
      collapsed: const <String>{},
      ungroupedTitle: 'Ungrouped',
    );

    test('move up past a row steps the folder up one place', () {
      // The screen reader's "move up" on header B: (2, 1).
      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 2,
        newIndex: 1,
        stepFolders: true,
      );
      expect(event, const ProfileGroupReorderFoldersEvent(<String>['B', 'A']));
    });

    test('move down past a row steps the folder down one place', () {
      final ProfileGroupEvent? event = layout.resolveDrop(
        oldIndex: 0,
        newIndex: 1,
        stepFolders: true,
      );
      expect(event, const ProfileGroupReorderFoldersEvent(<String>['B', 'A']));
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
