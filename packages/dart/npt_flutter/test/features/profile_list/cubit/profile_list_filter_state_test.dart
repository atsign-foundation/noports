import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/language.dart';

import '../view/profile_list_view_test.mocks.dart';

class _FakeFolderRepository extends ProfileFolderRepository {
  final List<ProfileFolderData> puts = <ProfileFolderData>[];

  @override
  Future<ProfileFolderData?> getProfileFolders() async => null;

  @override
  Future<bool> putProfileFolders(ProfileFolderData data) async {
    puts.add(data);
    return true;
  }
}

Profile buildProfile(
  String uuid,
  String displayName, {
  String deviceName = 'device',
  String? atsign,
}) => Profile(
  uuid,
  displayName: displayName,
  deviceName: deviceName,
  sshnpdAtsign: atsign?.toAtsign(),
  remotePort: 22,
  localPort: 2222,
);

ProfileFolder buildFolder(
  String uuid,
  String name, {
  List<String> profileIds = const <String>[],
  bool favorite = false,
}) => ProfileFolder(
  uuid: uuid,
  name: name,
  profileIds: profileIds,
  favorite: favorite,
);

Map<String, Profile> named(Map<String, String> displayNames) =>
    <String, Profile>{
      for (final MapEntry<String, String> e in displayNames.entries)
        e.key: buildProfile(e.key, e.value),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('search', () {
    final Map<String, Profile> profiles = <String, Profile>{
      'prod': buildProfile(
        'prod',
        'Production DB',
        deviceName: 'db-01',
        atsign: '@alice',
      ),
      'salle': buildProfile(
        'salle',
        'Écran salle',
        deviceName: 'salle-3',
        atsign: '@bob',
      ),
      'mac': buildProfile(
        'mac',
        'Staging',
        deviceName: 'Écran-Mac',
        atsign: '@carol',
      ),
    };
    const List<String> uuids = <String>['prod', 'salle', 'mac'];

    List<String> found(String query) => ProfileListFilterState(
      query: query,
      profiles: profiles,
    ).apply(uuids, const <String>{});

    test('an empty or blank query shows everything', () {
      for (final String query in <String>['', '   ']) {
        final ProfileListFilterState state = ProfileListFilterState(
          query: query,
          profiles: profiles,
        );
        expect(state.searching, isFalse, reason: 'query "$query"');
        expect(state.apply(uuids, const <String>{}), uuids);
        expect(state.hides('prod'), isFalse);
      }
    });

    test('matches the display name', () {
      expect(found('production'), <String>['prod']);
      expect(found('stag'), <String>['mac']);
    });

    test('matches the device name', () {
      expect(found('db-01'), <String>['prod']);
      expect(found('salle-3'), <String>['salle']);
    });

    test('matches the device atSign with or without the at sign', () {
      expect(found('alice'), <String>['prod']);
      expect(found('@alice'), <String>['prod']);
      expect(found('@car'), <String>['mac']);
    });

    test('ignores case in the query and in the names', () {
      expect(found('PRODUCTION'), <String>['prod']);
      expect(found('ÉCRAN SALLE'), <String>['salle']);
      expect(found('@ALICE'), <String>['prod']);
    });

    test('ignores accents in the display name and the device name', () {
      expect(found('ecran'), <String>['salle', 'mac']);
      expect(found('ecran salle'), <String>['salle']);
      expect(found('ecran-mac'), <String>['mac']);
    });

    test('ignores accents in the query', () {
      final ProfileListFilterState state = ProfileListFilterState(
        query: 'Écran',
        profiles: named(<String, String>{'plain': 'Ecran', 'other': 'Screen'}),
      );
      expect(
        state.apply(<String>['plain', 'other'], const <String>{}),
        <String>['plain'],
      );
    });

    test('ignores spaces around the query', () {
      expect(found('  alice  '), <String>['prod']);
    });

    test('keeps the order given for the connections that match', () {
      expect(found('e'), uuids);
      expect(
        ProfileListFilterState(
          query: 'e',
          profiles: profiles,
        ).apply(<String>['mac', 'prod', 'salle'], const <String>{}),
        <String>['mac', 'prod', 'salle'],
      );
    });

    test('a connection that has not loaded is not shown but not hidden', () {
      final ProfileListFilterState state = ProfileListFilterState(
        query: 'production',
        profiles: <String, Profile>{'prod': profiles['prod']!},
      );
      expect(state.matches('salle'), isFalse);
      expect(state.hides('salle'), isFalse);
      expect(state.apply(uuids, const <String>{}), <String>['prod']);
    });

    test('a loaded connection that does not match is hidden', () {
      final ProfileListFilterState state = ProfileListFilterState(
        query: 'production',
        profiles: profiles,
      );
      expect(state.hides('salle'), isTrue);
      expect(state.hides('prod'), isFalse);
    });

    test('a connection is settled once it has loaded or failed to load', () {
      final ProfileListFilterState state = ProfileListFilterState(
        profiles: <String, Profile>{'prod': profiles['prod']!},
        failed: const <String>{'salle'},
      );
      expect(state.settled('prod'), isTrue);
      expect(state.settled('salle'), isTrue);
      expect(state.settled('mac'), isFalse);
    });

    group('by folder name', () {
      final Map<String, Profile> folderProfiles = named(<String, String>{
        'a': 'Alpha',
        'b': 'Beta',
        'c': 'Gamma',
        'd': 'Delta',
      });
      const List<String> all = <String>['a', 'b', 'c', 'd'];

      ProfileListFilterState search(
        String query,
        List<ProfileFolder> folders, {
        Map<String, Profile>? loaded,
        ProfileSortMode sortMode = ProfileSortMode.manual,
      }) => ProfileListFilterState(
        query: query,
        sortMode: sortMode,
        profiles: loaded ?? folderProfiles,
        folders: folders,
      );

      test('a matching folder shows all of its connections', () {
        final ProfileListFilterState state = search('servers', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a', 'b']),
          buildFolder('f2', 'Desktops', profileIds: <String>['c']),
        ]);
        expect(state.apply(all, const <String>{}), <String>['a', 'b']);
        expect(state.folderMatches(state.folders.first), isTrue);
        expect(state.folderMatches(state.folders.last), isFalse);
        expect(state.anyFolderMatches, isTrue);
      });

      test('matches part of the folder name', () {
        final ProfileListFilterState state = search('serv', <ProfileFolder>[
          buildFolder('f1', 'Home servers', profileIds: <String>['a']),
        ]);
        expect(state.apply(all, const <String>{}), <String>['a']);
      });

      test('ignores case in folder names', () {
        for (final (String folder, String query) in <(String, String)>[
          ('SERVERS', 'servers'),
          ('servers', 'SERVERS'),
        ]) {
          final ProfileListFilterState state = search(query, <ProfileFolder>[
            buildFolder('f1', folder, profileIds: <String>['a']),
          ]);
          expect(state.apply(all, const <String>{}), <String>[
            'a',
          ], reason: '$folder searched as $query');
        }
      });

      test('ignores accents in folder names and in the query', () {
        for (final (String folder, String query) in <(String, String)>[
          ('Écran', 'ecran'),
          ('Ecran', 'écran'),
          ('Écrans de salle', 'ECRAN'),
        ]) {
          final ProfileListFilterState state = search(query, <ProfileFolder>[
            buildFolder('f1', folder, profileIds: <String>['a', 'b']),
          ]);
          expect(state.apply(all, const <String>{}), <String>[
            'a',
            'b',
          ], reason: '$folder searched as $query');
          expect(state.folderMatches(state.folders.single), isTrue);
        }
      });

      test('shows the connections of a matching folder before they load', () {
        final ProfileListFilterState state = search('servers', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a', 'b']),
        ], loaded: const <String, Profile>{});
        expect(state.matches('a'), isTrue);
        expect(state.hides('a'), isFalse);
        expect(state.matches('c'), isFalse);
        expect(state.apply(all, const <String>{}), <String>['a', 'b']);
      });

      test('a connection matching by itself shows without its folder', () {
        final ProfileListFilterState state = search('gamma', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a', 'c']),
        ]);
        expect(state.apply(all, const <String>{}), <String>['c']);
        expect(state.anyFolderMatches, isFalse);
      });

      test('a matching folder and a matching connection both show', () {
        final ProfileListFilterState state = search(
          'servers',
          <ProfileFolder>[
            buildFolder('f1', 'Servers', profileIds: <String>['a']),
          ],
          loaded: <String, Profile>{
            ...folderProfiles,
            'c': buildProfile('c', 'Servers backup'),
          },
        );
        expect(state.apply(all, const <String>{}), <String>['a', 'c']);
      });

      test('a connection only counts for the folder that holds it', () {
        final ProfileListFilterState state = search('desktops', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a']),
          buildFolder('f2', 'Desktops', profileIds: <String>['b']),
        ]);
        expect(state.apply(all, const <String>{}), <String>['b']);
      });

      test('a connection in no folder is not shown by a folder match', () {
        final ProfileListFilterState state = search('servers', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a']),
        ]);
        expect(state.matches('d'), isFalse);
      });

      test('folders match nothing without a query', () {
        for (final String query in <String>['', '  ']) {
          final ProfileListFilterState state = search(query, <ProfileFolder>[
            buildFolder('f1', 'Servers', profileIds: <String>['a']),
          ]);
          expect(state.folderMatches(state.folders.single), isFalse);
          expect(state.anyFolderMatches, isFalse);
        }
      });

      test('the matched connections still follow the sort', () {
        final ProfileListFilterState state = search('servers', <ProfileFolder>[
          buildFolder('f1', 'Servers', profileIds: <String>['a', 'd', 'b']),
        ], sortMode: ProfileSortMode.nameDescending);
        expect(state.apply(all, const <String>{}), <String>['d', 'b', 'a']);
      });
    });
  });

  group('connection order', () {
    // Manual order p1..p5. Folding puts Écran between banana and Zebra, and
    // lowercasing puts apple before Zebra. p4 and p5 tie.
    final Map<String, Profile> profiles = named(<String, String>{
      'p1': 'Zebra',
      'p2': 'apple',
      'p3': 'Écran',
      'p4': 'Banana',
      'p5': 'banana',
    });
    const List<String> manual = <String>['p1', 'p2', 'p3', 'p4', 'p5'];
    const Set<String> favorites = <String>{'p3', 'p5'};

    ProfileListFilterState state(ProfileSortMode mode, bool favoritesFirst) =>
        ProfileListFilterState(
          sortMode: mode,
          favoritesFirst: favoritesFirst,
          profiles: profiles,
        );

    final List<(String, ProfileSortMode, bool, List<String>)> cases =
        <(String, ProfileSortMode, bool, List<String>)>[
          (
            'manual',
            ProfileSortMode.manual,
            false,
            <String>['p1', 'p2', 'p3', 'p4', 'p5'],
          ),
          (
            'manual with favorites first',
            ProfileSortMode.manual,
            true,
            <String>['p3', 'p5', 'p1', 'p2', 'p4'],
          ),
          (
            'name ascending',
            ProfileSortMode.nameAscending,
            false,
            <String>['p2', 'p4', 'p5', 'p3', 'p1'],
          ),
          (
            'name ascending with favorites first',
            ProfileSortMode.nameAscending,
            true,
            <String>['p5', 'p3', 'p2', 'p4', 'p1'],
          ),
          (
            'name descending',
            ProfileSortMode.nameDescending,
            false,
            <String>['p1', 'p3', 'p4', 'p5', 'p2'],
          ),
          (
            'name descending with favorites first',
            ProfileSortMode.nameDescending,
            true,
            <String>['p3', 'p5', 'p1', 'p4', 'p2'],
          ),
        ];

    for (final (String label, ProfileSortMode mode, bool fav, List<String> want)
        in cases) {
      test('$label puts the connections in the expected order', () {
        expect(state(mode, fav).apply(manual, favorites), want);
      });
    }

    test('equal names keep the order the connections were given in', () {
      expect(
        state(
          ProfileSortMode.nameAscending,
          false,
        ).apply(<String>['p5', 'p4'], favorites),
        <String>['p5', 'p4'],
      );
      expect(
        state(
          ProfileSortMode.nameDescending,
          false,
        ).apply(<String>['p5', 'p4'], favorites),
        <String>['p5', 'p4'],
      );
    });

    test('favorites keep the given order among themselves', () {
      final ProfileListFilterState byFavorite = state(
        ProfileSortMode.manual,
        true,
      );
      expect(byFavorite.apply(<String>['p5', 'p3', 'p2'], favorites), <String>[
        'p5',
        'p3',
        'p2',
      ]);
      expect(byFavorite.apply(<String>['p3', 'p5', 'p2'], favorites), <String>[
        'p3',
        'p5',
        'p2',
      ]);
    });

    test('equal names stay in manual order in a long list', () {
      const List<String> names = <String>['delta', 'alpha', 'Charlie', 'BRAVO'];
      final List<String> many = <String>[for (int i = 0; i < 100; i++) 'u$i'];
      final ProfileListFilterState long = ProfileListFilterState(
        sortMode: ProfileSortMode.nameAscending,
        profiles: named(<String, String>{
          for (int i = 0; i < 100; i++) 'u$i': names[i % 4],
        }),
      );
      List<String> group(int k) => <String>[
        for (int i = 0; i < 100; i++)
          if (i % 4 == k) 'u$i',
      ];

      expect(long.apply(many, const <String>{}), <String>[
        ...group(1),
        ...group(3),
        ...group(2),
        ...group(0),
      ]);
      expect(
        long
            .copyWith(sortMode: ProfileSortMode.nameDescending)
            .apply(many, const <String>{}),
        <String>[...group(0), ...group(2), ...group(3), ...group(1)],
      );
    });

    test('sorting leaves the list it was given as it was', () {
      final List<String> given = List<String>.of(manual);
      state(ProfileSortMode.nameDescending, true).apply(given, favorites);
      expect(given, manual);
    });

    test('without a sort or favorites the order is only filtered', () {
      final ProfileListFilterState plain = state(ProfileSortMode.manual, false);
      expect(plain.apply(manual, favorites), manual);
      expect(plain.apply(<String>['p5', 'p1', 'p3'], favorites), <String>[
        'p5',
        'p1',
        'p3',
      ]);
    });

    test('a search narrows the list and then sorts what is left', () {
      final ProfileListFilterState searched = ProfileListFilterState(
        query: 'an',
        sortMode: ProfileSortMode.nameAscending,
        profiles: profiles,
      );
      expect(searched.apply(manual, const <String>{}), <String>[
        'p4',
        'p5',
        'p3',
      ]);
    });

    test('names fold the same way when sorting and when searching', () {
      final ProfileListFilterState ecran = ProfileListFilterState(
        query: 'ecran',
        sortMode: ProfileSortMode.nameAscending,
        profiles: profiles,
      );
      expect(ecran.apply(manual, const <String>{}), <String>['p3']);
    });
  });

  group('folder order', () {
    final List<ProfileFolder> folders = <ProfileFolder>[
      buildFolder('f1', 'Zebra'),
      buildFolder('f2', 'apple'),
      buildFolder('f3', 'Écran', favorite: true),
      buildFolder('f4', 'Banana'),
      buildFolder('f5', 'banana', favorite: true),
    ];

    ProfileListFilterState state(
      ProfileSortMode mode,
      bool favoritesFirst, {
      String query = '',
    }) => ProfileListFilterState(
      query: query,
      sortMode: mode,
      favoritesFirst: favoritesFirst,
      folders: folders,
    );

    List<String> shownOrder(ProfileListFilterState filter) =>
        ProfileFolderLayout.build(
          data: ProfileFolderData(folders: folders),
          loaded: const <String>[],
          collapsed: const <String>{},
          unfiledTitle: 'Unfiled',
          compareFolders: filter.folderOrder,
        ).folderIds;

    final List<(String, ProfileSortMode, bool, List<String>)> cases =
        <(String, ProfileSortMode, bool, List<String>)>[
          (
            'manual',
            ProfileSortMode.manual,
            false,
            <String>['f1', 'f2', 'f3', 'f4', 'f5'],
          ),
          (
            'manual with favorites first',
            ProfileSortMode.manual,
            true,
            <String>['f3', 'f5', 'f1', 'f2', 'f4'],
          ),
          (
            'name ascending',
            ProfileSortMode.nameAscending,
            false,
            <String>['f2', 'f4', 'f5', 'f3', 'f1'],
          ),
          (
            'name ascending with favorites first',
            ProfileSortMode.nameAscending,
            true,
            <String>['f5', 'f3', 'f2', 'f4', 'f1'],
          ),
          (
            'name descending',
            ProfileSortMode.nameDescending,
            false,
            <String>['f1', 'f3', 'f4', 'f5', 'f2'],
          ),
          (
            'name descending with favorites first',
            ProfileSortMode.nameDescending,
            true,
            <String>['f3', 'f5', 'f1', 'f4', 'f2'],
          ),
        ];

    for (final (String label, ProfileSortMode mode, bool fav, List<String> want)
        in cases) {
      test('$label puts the folders in the expected order', () {
        expect(shownOrder(state(mode, fav)), want);
      });
    }

    test('manual order without favorites first has no comparator', () {
      expect(state(ProfileSortMode.manual, false).folderOrder, isNull);
      expect(
        state(ProfileSortMode.manual, false, query: 'servers').folderOrder,
        isNull,
      );
    });

    test('a sort or favorites first has a comparator', () {
      expect(state(ProfileSortMode.manual, true).folderOrder, isNotNull);
      expect(
        state(ProfileSortMode.nameAscending, false).folderOrder,
        isNotNull,
      );
      expect(
        state(ProfileSortMode.nameDescending, false).folderOrder,
        isNotNull,
      );
    });

    test('equal names compare as equal whatever their case or accents', () {
      final int Function(ProfileFolder, ProfileFolder) ascending = state(
        ProfileSortMode.nameAscending,
        false,
      ).folderOrder!;
      final int Function(ProfileFolder, ProfileFolder) descending = state(
        ProfileSortMode.nameDescending,
        false,
      ).folderOrder!;
      final ProfileFolder lower = buildFolder('x', 'ecran');
      final ProfileFolder accented = buildFolder('y', 'Écran');
      expect(ascending(lower, accented), 0);
      expect(descending(lower, accented), 0);
    });

    test('name comparison runs in the direction of the sort', () {
      final ProfileFolder first = buildFolder('x', 'Apple');
      final ProfileFolder second = buildFolder('y', 'banana');
      final int Function(ProfileFolder, ProfileFolder) ascending = state(
        ProfileSortMode.nameAscending,
        false,
      ).folderOrder!;
      final int Function(ProfileFolder, ProfileFolder) descending = state(
        ProfileSortMode.nameDescending,
        false,
      ).folderOrder!;
      expect(ascending(first, second), isNegative);
      expect(ascending(second, first), isPositive);
      expect(descending(first, second), isPositive);
      expect(descending(second, first), isNegative);
    });

    test('favorites come first whatever the direction of the name sort', () {
      final ProfileFolder favorite = buildFolder('x', 'Zulu', favorite: true);
      final ProfileFolder other = buildFolder('y', 'Alpha');
      for (final ProfileSortMode mode in ProfileSortMode.values) {
        final int Function(ProfileFolder, ProfileFolder) compare = state(
          mode,
          true,
        ).folderOrder!;
        expect(compare(favorite, other), isNegative, reason: '$mode');
        expect(compare(other, favorite), isPositive, reason: '$mode');
      }
    });

    test('favorites only matter when they come first', () {
      final ProfileFolder favorite = buildFolder('x', 'Zulu', favorite: true);
      final ProfileFolder other = buildFolder('y', 'Alpha');
      final int Function(ProfileFolder, ProfileFolder) compare = state(
        ProfileSortMode.nameAscending,
        false,
      ).folderOrder!;
      expect(compare(favorite, other), isPositive);
    });

    test('with favorites first and manual order, same-kind folders tie', () {
      final int Function(ProfileFolder, ProfileFolder) compare = state(
        ProfileSortMode.manual,
        true,
      ).folderOrder!;
      expect(compare(folders[0], folders[1]), 0);
      expect(compare(folders[2], folders[4]), 0);
    });

    test('sorting folders and their connections leaves storage as it was', () {
      final Map<String, Profile> profiles = named(<String, String>{
        'p1': 'Zebra',
        'p2': 'apple',
        'p3': 'Écran',
        'p4': 'Mango',
        'p5': 'cherry',
      });
      final List<ProfileFolder> stored = <ProfileFolder>[
        buildFolder('f1', 'Zulu', profileIds: <String>['p1', 'p2', 'p3']),
        buildFolder('f2', 'Alpha', favorite: true),
      ];
      final ProfileFolderData data = ProfileFolderData(
        folders: stored,
        unfiled: const <String>['p4', 'p5'],
      );
      final ProfileListFilterState filter = ProfileListFilterState(
        sortMode: ProfileSortMode.nameAscending,
        favoritesFirst: true,
        profiles: profiles,
        folders: stored,
      );

      final ProfileFolderLayout layout = ProfileFolderLayout.build(
        data: data,
        loaded: const <String>['p1', 'p2', 'p3', 'p4', 'p5'],
        collapsed: const <String>{},
        unfiledTitle: 'Unfiled',
        arrange: (List<String> uuids) => filter.apply(uuids, const <String>{}),
        compareFolders: filter.folderOrder,
      );

      expect(layout.folderIds, <String>['f2', 'f1']);
      expect(
        layout.sections.map((ProfileFolderSection s) => s.uuids).toList(),
        <List<String>>[
          <String>[],
          <String>['p2', 'p3', 'p1'],
          <String>['p5', 'p4'],
        ],
      );
      expect(data.folders.map((ProfileFolder f) => f.uuid), <String>[
        'f1',
        'f2',
      ]);
      expect(data.folders.first.profileIds, <String>['p1', 'p2', 'p3']);
      expect(data.unfiled, <String>['p4', 'p5']);
    });
  });

  group('mode flags', () {
    ProfileListFilterState state({
      String query = '',
      ProfileSortMode mode = ProfileSortMode.manual,
      bool favoritesFirst = false,
    }) => ProfileListFilterState(
      query: query,
      sortMode: mode,
      favoritesFirst: favoritesFirst,
    );

    test('the default state is manual, unfiltered and not reordered', () {
      final ProfileListFilterState s = state();
      expect(s.isDefault, isTrue);
      expect(s.reordered, isFalse);
      expect(s.manualOrder, isTrue);
      expect(s.searching, isFalse);
      expect(s.needsProfiles, isFalse);
    });

    test('a blank query leaves the state default', () {
      final ProfileListFilterState s = state(query: '   ');
      expect(s.isDefault, isTrue);
      expect(s.manualOrder, isTrue);
      expect(s.needsProfiles, isFalse);
    });

    test('favorites first reorders but keeps drags reordering', () {
      final ProfileListFilterState s = state(favoritesFirst: true);
      expect(s.reordered, isTrue);
      expect(s.isDefault, isFalse);
      expect(s.manualOrder, isTrue);
      expect(s.needsProfiles, isFalse);
    });

    test('a name sort reorders and turns manual ordering off', () {
      for (final ProfileSortMode mode in <ProfileSortMode>[
        ProfileSortMode.nameAscending,
        ProfileSortMode.nameDescending,
      ]) {
        for (final bool favoritesFirst in <bool>[false, true]) {
          final ProfileListFilterState s = state(
            mode: mode,
            favoritesFirst: favoritesFirst,
          );
          final String reason = '$mode, favoritesFirst: $favoritesFirst';
          expect(s.reordered, isTrue, reason: reason);
          expect(s.isDefault, isFalse, reason: reason);
          expect(s.manualOrder, isFalse, reason: reason);
          expect(s.needsProfiles, isTrue, reason: reason);
        }
      }
    });

    test('a search is not default, not reordered and not manual', () {
      final ProfileListFilterState s = state(query: 'x');
      expect(s.searching, isTrue);
      expect(s.isDefault, isFalse);
      expect(s.reordered, isFalse);
      expect(s.manualOrder, isFalse);
      expect(s.needsProfiles, isTrue);
    });

    test('a search with favorites first is still reordered', () {
      final ProfileListFilterState s = state(query: 'x', favoritesFirst: true);
      expect(s.reordered, isTrue);
      expect(s.manualOrder, isFalse);
    });
  });

  group('dropping into a folder while sorted', () {
    const String alphaId = 'uuid-alpha';
    const String zetaId = 'uuid-zeta';
    const String midId = 'uuid-mid';
    const List<String> allUuids = <String>[zetaId, alphaId, midId];

    final Map<String, Profile> profiles = <String, Profile>{
      alphaId: buildProfile(alphaId, 'Alpha'),
      zetaId: buildProfile(zetaId, 'Zeta'),
      midId: buildProfile(midId, 'Mid'),
    };

    // Stored order is zeta, alpha; a name sort shows alpha, zeta.
    const ProfileFolder serversFolder = ProfileFolder(
      uuid: 'g-servers',
      name: 'Servers',
      profileIds: <String>[zetaId, alphaId],
    );

    final Settings testSettings = Settings(
      relayAtsign: '@rv_am'.toAtsign(),
      overrideRelay: false,
      viewLayout: PreferredViewLayout.minimal,
      language: Language.english,
    );

    late MockProfileCacheCubit mockCache;
    late MockSettingsBloc mockSettingsBloc;
    late MockProfilesSelectedCubit mockSelectedCubit;
    late MockProfileListBloc mockListBloc;
    late MockFavoriteBloc mockFavoriteBloc;
    late ProfilesRunningCubit runningCubit;
    late _FakeFolderRepository folderRepo;
    late ProfileFolderBloc folderBloc;

    setUp(() {
      provideDummy<ProfileState>(const ProfileInitial('dummy'));
      provideDummy<SettingsState>(const SettingsInitial());
      provideDummy<ProfilesSelectedState>(const ProfilesSelectedState({}));
      provideDummy<FavoritesState>(const FavoritesInitial());
      provideDummy<ProfileListState>(const ProfileListInitial());

      mockCache = MockProfileCacheCubit();
      profiles.forEach((String uuid, Profile profile) {
        final MockProfileBloc bloc = MockProfileBloc();
        final ProfileState state = ProfileLoaded(uuid, profile: profile);
        when(bloc.uuid).thenReturn(uuid);
        when(bloc.state).thenReturn(state);
        when(bloc.stream).thenAnswer((_) => Stream<ProfileState>.value(state));
        when(mockCache.getProfileBloc(uuid)).thenReturn(bloc);
      });

      mockSettingsBloc = MockSettingsBloc();
      when(
        mockSettingsBloc.state,
      ).thenReturn(SettingsLoaded(settings: testSettings));
      when(mockSettingsBloc.stream).thenAnswer(
        (_) =>
            Stream<SettingsState>.value(SettingsLoaded(settings: testSettings)),
      );

      mockListBloc = MockProfileListBloc();
      when(
        mockListBloc.state,
      ).thenReturn(const ProfileListLoaded(profiles: allUuids));
      when(mockListBloc.stream).thenAnswer(
        (_) => Stream<ProfileListState>.value(
          const ProfileListLoaded(profiles: allUuids),
        ),
      );

      mockSelectedCubit = MockProfilesSelectedCubit();
      when(mockSelectedCubit.state).thenReturn(const ProfilesSelectedState({}));
      when(mockSelectedCubit.stream).thenAnswer(
        (_) => Stream<ProfilesSelectedState>.value(
          const ProfilesSelectedState({}),
        ),
      );

      mockFavoriteBloc = MockFavoriteBloc();
      when(mockFavoriteBloc.state).thenReturn(const FavoritesLoaded([]));
      when(mockFavoriteBloc.stream).thenAnswer(
        (_) => Stream<FavoritesState>.value(const FavoritesLoaded([])),
      );
    });

    /// The real blocs must be created inside the test body so that their
    /// stream subscriptions live in the FakeAsync zone driven by the tester.
    void createRealBlocs() {
      runningCubit = ProfilesRunningCubit();
      folderRepo = _FakeFolderRepository();
      folderBloc = ProfileFolderBloc(folderRepo);
      addTearDown(() async {
        await runningCubit.close();
        await folderBloc.close();
      });
    }

    Widget buildSubject(WidgetTester tester, ProfileListFilterState filter) {
      tester.view.physicalSize = const Size(1053, 691);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      return MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ProfileCacheCubit>.value(value: mockCache),
          BlocProvider<SettingsBloc>.value(value: mockSettingsBloc),
          BlocProvider<ProfilesSelectedCubit>.value(value: mockSelectedCubit),
          BlocProvider<FavoriteBloc>.value(value: mockFavoriteBloc),
          BlocProvider<ProfilesRunningCubit>.value(value: runningCubit),
          BlocProvider<ProfileStartQueueCubit>(
            create: (_) => ProfileStartQueueCubit(mockCache),
          ),
          BlocProvider<ProfileFolderBloc>.value(value: folderBloc),
          BlocProvider<ProfileListBloc>.value(value: mockListBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ProfileFolderListView(
              profiles: allUuids,
              arrange: (List<String> uuids) =>
                  filter.apply(uuids, const <String>{}),
              compareFolders: filter.folderOrder,
              reorderable: filter.manualOrder,
              movable: !filter.searching,
            ),
          ),
        ),
      );
    }

    Finder header(String id) =>
        find.byKey(ValueKey<String>('ProfileFolderSectionHeader-$id'));
    Finder row(String uuid) =>
        find.byKey(ValueKey<String>('ProfileListRow-$uuid'));
    Finder grip(Finder item) => find.descendant(
      of: item,
      matching: find.byKey(const Key('ProfileDragHandle')),
    );

    void expectVerticalOrder(WidgetTester tester, List<Finder> finders) {
      for (final Finder f in finders) {
        expect(f, findsOneWidget);
      }
      for (int i = 1; i < finders.length; i++) {
        expect(
          tester.getTopLeft(finders[i - 1]).dy,
          lessThan(tester.getTopLeft(finders[i]).dy),
          reason: '${finders[i - 1]} should be above ${finders[i]}',
        );
      }
    }

    const Duration frame = Duration(milliseconds: 16);

    Future<void> dragGrip(WidgetTester tester, Finder item, double dy) async {
      expect(grip(item), findsOneWidget);
      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(grip(item)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      const int steps = 10;
      for (int i = 0; i < steps; i++) {
        await gesture.moveBy(Offset(0, dy / steps));
        await tester.pump(frame);
      }
      await tester.pump(const Duration(milliseconds: 100));
      await gesture.up();
      for (
        Duration t = Duration.zero;
        t < const Duration(milliseconds: 400);
        t += frame
      ) {
        await tester.pump(frame);
      }
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 400));
    }

    Future<void> showSorted(WidgetTester tester) async {
      createRealBlocs();
      folderBloc.emit(
        const ProfileFoldersLoaded(
          ProfileFolderData(
            folders: <ProfileFolder>[serversFolder],
            unfiled: <String>[midId],
          ),
        ),
      );
      await tester.pumpWidget(
        buildSubject(
          tester,
          ProfileListFilterState(
            sortMode: ProfileSortMode.nameAscending,
            profiles: profiles,
            folders: const <ProfileFolder>[serversFolder],
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('rows show sorted while the stored order stays manual', (
      WidgetTester tester,
    ) async {
      await showSorted(tester);

      expectVerticalOrder(tester, <Finder>[
        header(serversFolder.uuid),
        row(alphaId),
        row(zetaId),
        header(ProfileFolderListView.unfiledSectionId),
        row(midId),
      ]);
      expect(folderRepo.puts, isEmpty);
    });

    testWidgets('a row dropped into a folder goes to the end of its stored '
        'order', (WidgetTester tester) async {
      await showSorted(tester);

      // Released between Alpha and Zeta, where a manual drop would insert it.
      final double dy =
          tester.getTopLeft(row(zetaId)).dy - tester.getTopLeft(row(midId)).dy;
      await dragGrip(tester, row(midId), dy);

      expect(folderRepo.puts, hasLength(1));
      final ProfileFolderData saved = folderRepo.puts.single;
      expect(saved.folders.single.uuid, serversFolder.uuid);
      expect(saved.folders.single.profileIds, <String>[zetaId, alphaId, midId]);
      expect(saved.unfiled, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        header(serversFolder.uuid),
        row(alphaId),
        row(midId),
        row(zetaId),
        header(ProfileFolderListView.unfiledSectionId),
      ]);
    });

    testWidgets('a row dropped inside its own folder changes nothing', (
      WidgetTester tester,
    ) async {
      await showSorted(tester);

      await dragGrip(
        tester,
        row(zetaId),
        -tester.getSize(row(alphaId)).height * 1.1,
      );

      expect(folderRepo.puts, isEmpty);
      expectVerticalOrder(tester, <Finder>[
        header(serversFolder.uuid),
        row(alphaId),
        row(zetaId),
        header(ProfileFolderListView.unfiledSectionId),
        row(midId),
      ]);
    });

    testWidgets('folder headers have no grip while sorted by name', (
      WidgetTester tester,
    ) async {
      await showSorted(tester);

      expect(grip(header(serversFolder.uuid)), findsNothing);
      expect(grip(row(alphaId)), findsOneWidget);
    });
  });
}
