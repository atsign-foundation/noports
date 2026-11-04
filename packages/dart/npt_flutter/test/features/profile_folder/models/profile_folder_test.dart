import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';

// Asserts no id appears twice across all folders plus unfiled.
void _expectNoDuplicateIds(ProfileFolderData data) {
  final List<String> allIds = <String>[
    for (final ProfileFolder folder in data.folders) ...folder.profileIds,
    ...data.unfiled,
  ];
  expect(
    allIds.toSet().length,
    allIds.length,
    reason: 'duplicate id across folders/unfiled: $allIds',
  );
}

void main() {
  group('ProfileFolder', () {
    const ProfileFolder folder = ProfileFolder(
      uuid: 'g1',
      name: 'Servers',
      profileIds: <String>['a', 'b'],
    );

    test('json round trip', () {
      final Map<String, dynamic> json = jsonDecode(jsonEncode(folder.toJson()));
      expect(ProfileFolder.fromJson(json), equals(folder));
    });

    test('fromJson tolerates missing and malformed fields', () {
      final ProfileFolder parsed = ProfileFolder.fromJson(<String, dynamic>{
        'uuid': 'g2',
        'profileIds': <dynamic>['x', 1, null, 'y'],
      });
      expect(parsed.uuid, 'g2');
      expect(parsed.name, '');
      expect(parsed.profileIds, <String>['x', 'y']);
    });

    test('withoutProfiles removes only the given ids', () {
      expect(folder.withoutProfiles(<String>['b', 'zzz']).profileIds, <String>[
        'a',
      ]);
    });

    test('withProfiles appends without duplicates', () {
      expect(folder.withProfiles(<String>['b', 'c']).profileIds, <String>[
        'a',
        'b',
        'c',
      ]);
    });

    test('containsProfile and copyWith', () {
      expect(folder.containsProfile('a'), isTrue);
      expect(folder.containsProfile('c'), isFalse);
      expect(folder.copyWith(name: 'Renamed').name, 'Renamed');
      expect(folder.copyWith(name: 'Renamed').uuid, 'g1');
    });
  });

  group('ProfileFolderData', () {
    const ProfileFolderData data = ProfileFolderData(
      folders: <ProfileFolder>[
        ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a']),
        ProfileFolder(uuid: 'g2', name: 'Two', profileIds: <String>['b', 'c']),
      ],
    );

    test('json round trip', () {
      final Map<String, dynamic> json = jsonDecode(jsonEncode(data.toJson()));
      expect(ProfileFolderData.fromJson(json), equals(data));
    });

    test('defaults when json is empty', () {
      final ProfileFolderData parsed = ProfileFolderData.fromJson(
        <String, dynamic>{},
      );
      expect(parsed.folders, isEmpty);
    });

    test('fields a newer version adds survive an edit and a save', () {
      final Map<String, dynamic> stored = <String, dynamic>{
        'folders': <dynamic>[
          <String, dynamic>{
            'uuid': 'g1',
            'name': 'One',
            'profileIds': <String>['a'],
            'startAtLaunch': true,
          },
        ],
        'unfiled': <String>['b'],
        'layoutVersion': 2,
      };
      final ProfileFolderData edited = ProfileFolderData.fromJson(stored)
          .placeProfiles(
            profileIds: <String>['b'],
            folderId: 'g1',
            sectionOrder: <String>['b', 'a'],
          );
      expect(edited.toJson(), <String, dynamic>{
        'layoutVersion': 2,
        'folders': <dynamic>[
          <String, dynamic>{
            'startAtLaunch': true,
            'uuid': 'g1',
            'name': 'One',
            'profileIds': <String>['b', 'a'],
          },
        ],
        'unfiled': <String>[],
      });
    });

    test('fromJson drops folders without a uuid and non-map entries', () {
      final ProfileFolderData parsed = ProfileFolderData.fromJson(
        <String, dynamic>{
          'folders': <dynamic>[
            <String, dynamic>{'name': 'no uuid'},
            'junk',
            <String, dynamic>{'uuid': 'ok', 'name': 'Ok'},
          ],
        },
      );
      expect(parsed.folders.map((ProfileFolder f) => f.uuid), <String>['ok']);
    });

    test('folderForProfile and folderById', () {
      expect(data.folderForProfile('c')?.uuid, 'g2');
      expect(data.folderForProfile('zzz'), isNull);
      expect(data.folderById('g1')?.name, 'One');
      expect(data.folderById('nope'), isNull);
    });

    test('json round trip includes unfiled', () {
      const ProfileFolderData withUnfiled = ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a']),
        ],
        unfiled: <String>['x', 'y'],
      );
      final Map<String, dynamic> json = jsonDecode(
        jsonEncode(withUnfiled.toJson()),
      );
      expect(json['unfiled'], <String>['x', 'y']);
      expect(ProfileFolderData.fromJson(json), equals(withUnfiled));
    });

    group('fromJson normalisation', () {
      test('an id in two folders keeps the first', () {
        final ProfileFolderData parsed = ProfileFolderData.fromJson(
          <String, dynamic>{
            'folders': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'One',
                'profileIds': <String>['a', 'b'],
              },
              <String, dynamic>{
                'uuid': 'g2',
                'name': 'Two',
                'profileIds': <String>['b', 'c'],
              },
            ],
          },
        );
        expect(parsed.folderById('g1')?.profileIds, <String>['a', 'b']);
        expect(parsed.folderById('g2')?.profileIds, <String>['c']);
        _expectNoDuplicateIds(parsed);
      });

      test('an id in a folder and in unfiled stays in the folder', () {
        final ProfileFolderData parsed = ProfileFolderData.fromJson(
          <String, dynamic>{
            'folders': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'One',
                'profileIds': <String>['a'],
              },
            ],
            'unfiled': <String>['a', 'b'],
          },
        );
        expect(parsed.folderById('g1')?.profileIds, <String>['a']);
        expect(parsed.unfiled, <String>['b']);
        _expectNoDuplicateIds(parsed);
      });

      test('a repeated folder uuid keeps the first name and merges the '
          'members', () {
        final ProfileFolderData parsed = ProfileFolderData.fromJson(
          <String, dynamic>{
            'folders': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'First',
                'profileIds': <String>['a'],
              },
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'Second',
                'profileIds': <String>['b'],
              },
            ],
          },
        );
        expect(parsed.folders.length, 1);
        expect(parsed.folders.single.name, 'First');
        expect(parsed.folders.single.profileIds, <String>['a', 'b']);
        _expectNoDuplicateIds(parsed);
      });

      test('non-string unfiled entries are dropped', () {
        final ProfileFolderData parsed = ProfileFolderData.fromJson(
          <String, dynamic>{
            'folders': <dynamic>[],
            'unfiled': <dynamic>['a', 1, null, 'b', true],
          },
        );
        expect(parsed.unfiled, <String>['a', 'b']);
      });

      test('missing unfiled defaults to an empty list', () {
        final ProfileFolderData parsed = ProfileFolderData.fromJson(
          <String, dynamic>{
            'folders': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'One',
                'profileIds': <String>['a'],
              },
            ],
          },
        );
        expect(parsed.unfiled, isEmpty);
        expect(parsed.folderById('g1')?.profileIds, <String>['a']);
      });
    });

    group('resolveUnfiled', () {
      test('stored order first, then loaded order; skips unloaded and '
          'folder-claimed ids; no duplicates', () {
        const ProfileFolderData resolveData = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a']),
            ProfileFolder(uuid: 'g2', name: 'Two', profileIds: <String>['b']),
          ],
          // 'f' is stored but never loaded; 'd' repeated to prove
          // dedup; 'a' stored despite being folder-claimed.
          unfiled: <String>['f', 'd', 'd', 'c', 'a'],
        );
        final List<String> resolved = resolveData.resolveUnfiled(<String>[
          'a',
          'b',
          'c',
          'd',
          'e',
        ]);
        // 'f' skipped (not loaded), 'a' skipped (claimed by g1), then 'e'
        // appended from loaded order.
        expect(resolved, <String>['d', 'c', 'e']);
      });
    });

    test('withoutProfilesEverywhere removes ids from every folder and '
        'unfiled', () {
      const ProfileFolderData toStrip = ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(
            uuid: 'g1',
            name: 'One',
            profileIds: <String>['a', 'b'],
          ),
          ProfileFolder(uuid: 'g2', name: 'Two', profileIds: <String>['c']),
        ],
        unfiled: <String>['d', 'e'],
      );
      final ProfileFolderData stripped = toStrip.withoutProfilesEverywhere(
        <String>['b', 'd', 'zzz'],
      );
      expect(stripped.folderById('g1')?.profileIds, <String>['a']);
      expect(stripped.folderById('g2')?.profileIds, <String>['c']);
      expect(stripped.unfiled, <String>['e']);
      _expectNoDuplicateIds(stripped);
    });

    group('withProfilesUnfiled', () {
      const ProfileFolderData base = ProfileFolderData(
        folders: <ProfileFolder>[
          ProfileFolder(
            uuid: 'g1',
            name: 'One',
            profileIds: <String>['a', 'b'],
          ),
        ],
      );

      test('is a no-op when none of the ids is in a folder', () {
        // "No folder" picked for a connection that is already unfiled.
        expect(
          base.withProfilesUnfiled(
            <String>['x'],
            visibleUnfiled: <String>['x', 'y'],
          ),
          same(base),
        );
      });

      test('puts moved ids after every connection the list shows, including '
          'never-dragged ones', () {
        final ProfileFolderData moved = base.withProfilesUnfiled(
          <String>['a'],
          visibleUnfiled: <String>['x', 'y'],
        );
        expect(moved.folderById('g1')?.profileIds, <String>['b']);
        expect(moved.unfiled, <String>['x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('already-unfiled ids in the request keep their place', () {
        final ProfileFolderData moved = base.withProfilesUnfiled(
          <String>['x', 'a'],
          visibleUnfiled: <String>['x', 'y'],
        );
        expect(moved.unfiled, <String>['x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('keeps a stored unfiled id this device cannot show', () {
        final ProfileFolderData withHidden = base.copyWith(
          unfiled: <String>['h', 'x'],
        );
        final ProfileFolderData moved = withHidden.withProfilesUnfiled(
          <String>['a'],
          visibleUnfiled: <String>['x', 'y'],
        );
        expect(moved.unfiled, <String>['h', 'x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('without the visible order, only strips folders and leaves the '
          'stored order alone', () {
        final ProfileFolderData moved = base.withProfilesUnfiled(<String>['a']);
        expect(moved.folderById('g1')?.profileIds, <String>['b']);
        expect(moved.unfiled, isEmpty);
      });
    });

    group('mergeVisibleOrder', () {
      test('a hidden id stays before the next visible id that followed it', () {
        final List<String> merged = ProfileFolderData.mergeVisibleOrder(
          <String>['a', 'h1', 'b', 'h2', 'c'],
          <String>['c', 'a', 'b'],
        );
        expect(merged, <String>['h2', 'c', 'a', 'h1', 'b']);
      });

      test('trailing hidden ids stay at the end', () {
        final List<String> merged = ProfileFolderData.mergeVisibleOrder(
          <String>['a', 'b', 'h1', 'h2'],
          <String>['b', 'a'],
        );
        expect(merged, <String>['b', 'a', 'h1', 'h2']);
      });

      test('new visible ids are included', () {
        final List<String> merged = ProfileFolderData.mergeVisibleOrder(
          <String>['a', 'b'],
          <String>['a', 'c', 'b'],
        );
        expect(merged, <String>['a', 'c', 'b']);
      });
    });

    group('placeInManualOrder', () {
      // B and D are favorites: Favorites first lifts them above A and C.
      const Set<String> favorites = <String>{'B', 'D'};
      bool tie(String a, String b) =>
          favorites.contains(a) == favorites.contains(b);
      List<String> place(
        List<String> manual,
        List<String> released,
        List<String> moved,
      ) => ProfileFolderData.placeInManualOrder(
        manual: manual,
        released: released,
        moved: moved,
        tie: tie,
      );

      test('dragging C above A keeps the favorites where they were', () {
        expect(
          place(
            <String>['A', 'B', 'C', 'D'],
            <String>['B', 'D', 'C', 'A'],
            <String>['C'],
          ),
          <String>['C', 'A', 'B', 'D'],
        );
      });

      test('a drop that leaves the screen as it was changes nothing', () {
        // A dropped above the favorites still shows below them.
        expect(
          place(
            <String>['A', 'B', 'C', 'D'],
            <String>['A', 'B', 'D', 'C'],
            <String>['A'],
          ),
          <String>['A', 'B', 'C', 'D'],
        );
      });

      test('a drop below every tie goes after the last of them', () {
        expect(
          place(
            <String>['A', 'B', 'C', 'D'],
            <String>['B', 'D', 'C', 'A'],
            <String>['A'],
          ),
          <String>['B', 'C', 'A', 'D'],
        );
      });

      test('a favorite dragged to the top goes before the first favorite', () {
        expect(
          place(
            <String>['A', 'B', 'C', 'D'],
            <String>['D', 'B', 'A', 'C'],
            <String>['D'],
          ),
          <String>['A', 'D', 'B', 'C'],
        );
      });

      test('a mixed selection places each kind among its own', () {
        // Screen before: B, D, A, C. C and B are dragged to the top.
        expect(
          place(
            <String>['A', 'B', 'C', 'D'],
            <String>['B', 'C', 'D', 'A'],
            <String>['B', 'C'],
          ),
          <String>['C', 'A', 'B', 'D'],
        );
      });

      test('an id moved in from elsewhere goes before its next tie', () {
        expect(
          place(<String>['A', 'B'], <String>['B', 'X', 'A'], <String>['X']),
          <String>['X', 'A', 'B'],
        );
      });

      test('an id with nothing to tie with goes last', () {
        expect(
          place(<String>['B'], <String>['X', 'B'], <String>['X']),
          <String>['B', 'X'],
        );
      });
    });

    group('placeProfiles', () {
      test('into a folder at a position', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b', 'c'],
            ),
            ProfileFolder(uuid: 'g2', name: 'Two', profileIds: <String>['x']),
          ],
          unfiled: <String>['z'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['z'],
          folderId: 'g1',
          sectionOrder: <String>['a', 'z', 'b', 'c'],
        );
        expect(result.folderById('g1')?.profileIds, <String>[
          'a',
          'z',
          'b',
          'c',
        ]);
        expect(result.folderById('g2')?.profileIds, <String>['x']);
        expect(result.unfiled, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('into unfiled', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b'],
            ),
          ],
          unfiled: <String>['c', 'd'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['b'],
          folderId: null,
          sectionOrder: <String>['c', 'b', 'd'],
        );
        expect(result.folderById('g1')?.profileIds, <String>['a']);
        expect(result.unfiled, <String>['c', 'b', 'd']);
        _expectNoDuplicateIds(result);
      });

      test('moving between folders', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b'],
            ),
            ProfileFolder(
              uuid: 'g2',
              name: 'Two',
              profileIds: <String>['x', 'y'],
            ),
          ],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['b'],
          folderId: 'g2',
          sectionOrder: <String>['x', 'b', 'y'],
        );
        expect(result.folderById('g1')?.profileIds, <String>['a']);
        expect(result.folderById('g2')?.profileIds, <String>['x', 'b', 'y']);
        _expectNoDuplicateIds(result);
      });

      test('keeps a hidden stored id in place', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              // 'h' is stored but not currently loaded, so the view's
              // sectionOrder below cannot show it.
              profileIds: <String>['a', 'h', 'b'],
            ),
          ],
          unfiled: <String>['c'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['c'],
          folderId: 'g1',
          sectionOrder: <String>['a', 'c', 'b'],
        );
        expect(result.folderById('g1')?.profileIds, <String>[
          'a',
          'c',
          'h',
          'b',
        ]);
        expect(result.unfiled, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('ignores an id the view shows in the target that another folder '
          'now holds (stale view)', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            // A concurrent sync already moved 'x' into g1; the dragging
            // view's sectionOrder for g2 below has not caught up.
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'x'],
            ),
            ProfileFolder(uuid: 'g2', name: 'Two', profileIds: <String>['y']),
          ],
          unfiled: <String>['z'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['z'],
          folderId: 'g2',
          sectionOrder: <String>['y', 'x', 'z'],
        );
        expect(result.folderById('g1')?.profileIds, <String>['a', 'x']);
        expect(result.folderById('g2')?.profileIds, <String>['y', 'z']);
        expect(result.unfiled, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('a multi-id move', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b', 'c'],
            ),
          ],
          unfiled: <String>['d', 'e'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['b', 'e'],
          folderId: 'g1',
          sectionOrder: <String>['a', 'e', 'b', 'c'],
        );
        expect(result.folderById('g1')?.profileIds, <String>[
          'a',
          'e',
          'b',
          'c',
        ]);
        expect(result.unfiled, <String>['d']);
        _expectNoDuplicateIds(result);
      });

      test('an unknown folderId returns the data unchanged', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a']),
          ],
          unfiled: <String>['b'],
        );
        final ProfileFolderData result = base.placeProfiles(
          profileIds: <String>['a'],
          folderId: 'nope',
          sectionOrder: <String>['a'],
        );
        expect(result, equals(base));
        expect(identical(result, base), isTrue);
      });
    });

    group('withFoldersOrdered', () {
      test('unknown and repeated ids are ignored; unnamed folders are '
          'appended in current order', () {
        const ProfileFolderData base = ProfileFolderData(
          folders: <ProfileFolder>[
            ProfileFolder(uuid: 'g1', name: 'One'),
            ProfileFolder(uuid: 'g2', name: 'Two'),
            ProfileFolder(uuid: 'g3', name: 'Three'),
          ],
        );
        final ProfileFolderData result = base.withFoldersOrdered(<String>[
          'g2',
          'bogus',
          'g2',
          'g1',
        ]);
        expect(result.folders.map((ProfileFolder f) => f.uuid), <String>[
          'g2',
          'g1',
          'g3',
        ]);
      });
    });
  });
}
