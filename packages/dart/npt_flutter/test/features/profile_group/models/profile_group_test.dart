import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';

// Asserts no id appears twice across all folders plus ungrouped.
void _expectNoDuplicateIds(ProfileGroupData data) {
  final List<String> allIds = <String>[
    for (final ProfileGroup group in data.groups) ...group.profileIds,
    ...data.ungrouped,
  ];
  expect(
    allIds.toSet().length,
    allIds.length,
    reason: 'duplicate id across folders/ungrouped: $allIds',
  );
}

void main() {
  group('ProfileGroup', () {
    const ProfileGroup group = ProfileGroup(
      uuid: 'g1',
      name: 'Servers',
      profileIds: <String>['a', 'b'],
    );

    test('json round trip', () {
      final Map<String, dynamic> json = jsonDecode(jsonEncode(group.toJson()));
      expect(ProfileGroup.fromJson(json), equals(group));
    });

    test('fromJson tolerates missing and malformed fields', () {
      final ProfileGroup parsed = ProfileGroup.fromJson(<String, dynamic>{
        'uuid': 'g2',
        'profileIds': <dynamic>['x', 1, null, 'y'],
      });
      expect(parsed.uuid, 'g2');
      expect(parsed.name, '');
      expect(parsed.profileIds, <String>['x', 'y']);
    });

    test('withoutProfiles removes only the given ids', () {
      expect(group.withoutProfiles(<String>['b', 'zzz']).profileIds, <String>[
        'a',
      ]);
    });

    test('withProfiles appends without duplicates', () {
      expect(group.withProfiles(<String>['b', 'c']).profileIds, <String>[
        'a',
        'b',
        'c',
      ]);
    });

    test('containsProfile and copyWith', () {
      expect(group.containsProfile('a'), isTrue);
      expect(group.containsProfile('c'), isFalse);
      expect(group.copyWith(name: 'Renamed').name, 'Renamed');
      expect(group.copyWith(name: 'Renamed').uuid, 'g1');
    });
  });

  group('ProfileGroupData', () {
    const ProfileGroupData data = ProfileGroupData(
      groups: <ProfileGroup>[
        ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a']),
        ProfileGroup(uuid: 'g2', name: 'Two', profileIds: <String>['b', 'c']),
      ],
    );

    test('json round trip', () {
      final Map<String, dynamic> json = jsonDecode(jsonEncode(data.toJson()));
      expect(ProfileGroupData.fromJson(json), equals(data));
    });

    test('defaults when json is empty', () {
      final ProfileGroupData parsed = ProfileGroupData.fromJson(
        <String, dynamic>{},
      );
      expect(parsed.groups, isEmpty);
    });

    test('fromJson ignores the retired sortByType flag', () {
      final Map<String, dynamic> legacy = <String, dynamic>{
        ...data.toJson(),
        'sortByType': true,
      };
      final ProfileGroupData parsed = ProfileGroupData.fromJson(legacy);
      expect(parsed, equals(data));
      expect(parsed.toJson().containsKey('sortByType'), isFalse);
    });

    test('fromJson drops groups without a uuid and non-map entries', () {
      final ProfileGroupData parsed = ProfileGroupData.fromJson(
        <String, dynamic>{
          'groups': <dynamic>[
            <String, dynamic>{'name': 'no uuid'},
            'junk',
            <String, dynamic>{'uuid': 'ok', 'name': 'Ok'},
          ],
        },
      );
      expect(parsed.groups.map((ProfileGroup g) => g.uuid), <String>['ok']);
    });

    test('groupForProfile and groupById', () {
      expect(data.groupForProfile('c')?.uuid, 'g2');
      expect(data.groupForProfile('zzz'), isNull);
      expect(data.groupById('g1')?.name, 'One');
      expect(data.groupById('nope'), isNull);
    });

    test('json round trip includes ungrouped', () {
      const ProfileGroupData withUngrouped = ProfileGroupData(
        groups: <ProfileGroup>[
          ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a']),
        ],
        ungrouped: <String>['x', 'y'],
      );
      final Map<String, dynamic> json = jsonDecode(
        jsonEncode(withUngrouped.toJson()),
      );
      expect(json['ungrouped'], <String>['x', 'y']);
      expect(ProfileGroupData.fromJson(json), equals(withUngrouped));
    });

    group('fromJson normalisation', () {
      test('an id in two folders keeps the first', () {
        final ProfileGroupData parsed = ProfileGroupData.fromJson(
          <String, dynamic>{
            'groups': <dynamic>[
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
        expect(parsed.groupById('g1')?.profileIds, <String>['a', 'b']);
        expect(parsed.groupById('g2')?.profileIds, <String>['c']);
        _expectNoDuplicateIds(parsed);
      });

      test('an id in a folder and in ungrouped stays in the folder', () {
        final ProfileGroupData parsed = ProfileGroupData.fromJson(
          <String, dynamic>{
            'groups': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'One',
                'profileIds': <String>['a'],
              },
            ],
            'ungrouped': <String>['a', 'b'],
          },
        );
        expect(parsed.groupById('g1')?.profileIds, <String>['a']);
        expect(parsed.ungrouped, <String>['b']);
        _expectNoDuplicateIds(parsed);
      });

      test('a repeated group uuid keeps the first name and merges the '
          'members', () {
        final ProfileGroupData parsed = ProfileGroupData.fromJson(
          <String, dynamic>{
            'groups': <dynamic>[
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
        expect(parsed.groups.length, 1);
        expect(parsed.groups.single.name, 'First');
        expect(parsed.groups.single.profileIds, <String>['a', 'b']);
        _expectNoDuplicateIds(parsed);
      });

      test('non-string ungrouped entries are dropped', () {
        final ProfileGroupData parsed = ProfileGroupData.fromJson(
          <String, dynamic>{
            'groups': <dynamic>[],
            'ungrouped': <dynamic>['a', 1, null, 'b', true],
          },
        );
        expect(parsed.ungrouped, <String>['a', 'b']);
      });

      test('missing ungrouped defaults to an empty list', () {
        final ProfileGroupData parsed = ProfileGroupData.fromJson(
          <String, dynamic>{
            'groups': <dynamic>[
              <String, dynamic>{
                'uuid': 'g1',
                'name': 'One',
                'profileIds': <String>['a'],
              },
            ],
          },
        );
        expect(parsed.ungrouped, isEmpty);
        expect(parsed.groupById('g1')?.profileIds, <String>['a']);
      });
    });

    group('resolveUngrouped', () {
      test('stored order first, then loaded order; skips unloaded and '
          'folder-claimed ids; no duplicates', () {
        const ProfileGroupData resolveData = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a']),
            ProfileGroup(uuid: 'g2', name: 'Two', profileIds: <String>['b']),
          ],
          // 'f' is stored but never loaded; 'd' repeated to prove
          // dedup; 'a' stored despite being folder-claimed.
          ungrouped: <String>['f', 'd', 'd', 'c', 'a'],
        );
        final List<String> resolved = resolveData.resolveUngrouped(<String>[
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
        'ungrouped', () {
      const ProfileGroupData toStrip = ProfileGroupData(
        groups: <ProfileGroup>[
          ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a', 'b']),
          ProfileGroup(uuid: 'g2', name: 'Two', profileIds: <String>['c']),
        ],
        ungrouped: <String>['d', 'e'],
      );
      final ProfileGroupData stripped = toStrip.withoutProfilesEverywhere(
        <String>['b', 'd', 'zzz'],
      );
      expect(stripped.groupById('g1')?.profileIds, <String>['a']);
      expect(stripped.groupById('g2')?.profileIds, <String>['c']);
      expect(stripped.ungrouped, <String>['e']);
      _expectNoDuplicateIds(stripped);
    });

    group('withProfilesUngrouped', () {
      const ProfileGroupData base = ProfileGroupData(
        groups: <ProfileGroup>[
          ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a', 'b']),
        ],
      );

      test('is a no-op when none of the ids is in a folder', () {
        // "No folder" picked for a connection that is already ungrouped.
        expect(
          base.withProfilesUngrouped(
            <String>['x'],
            visibleUngrouped: <String>['x', 'y'],
          ),
          same(base),
        );
      });

      test('puts moved ids after every connection the list shows, including '
          'never-dragged ones', () {
        final ProfileGroupData moved = base.withProfilesUngrouped(
          <String>['a'],
          visibleUngrouped: <String>['x', 'y'],
        );
        expect(moved.groupById('g1')?.profileIds, <String>['b']);
        expect(moved.ungrouped, <String>['x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('already-ungrouped ids in the request keep their place', () {
        final ProfileGroupData moved = base.withProfilesUngrouped(
          <String>['x', 'a'],
          visibleUngrouped: <String>['x', 'y'],
        );
        expect(moved.ungrouped, <String>['x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('keeps a stored ungrouped id this device cannot show', () {
        final ProfileGroupData withHidden = base.copyWith(
          ungrouped: <String>['h', 'x'],
        );
        final ProfileGroupData moved = withHidden.withProfilesUngrouped(
          <String>['a'],
          visibleUngrouped: <String>['x', 'y'],
        );
        expect(moved.ungrouped, <String>['h', 'x', 'y', 'a']);
        _expectNoDuplicateIds(moved);
      });

      test('without the visible order, only strips folders and leaves the '
          'stored order alone', () {
        final ProfileGroupData moved = base.withProfilesUngrouped(<String>[
          'a',
        ]);
        expect(moved.groupById('g1')?.profileIds, <String>['b']);
        expect(moved.ungrouped, isEmpty);
      });
    });

    group('mergeVisibleOrder', () {
      test('a hidden id stays before the next visible id that followed it', () {
        final List<String> merged = ProfileGroupData.mergeVisibleOrder(
          <String>['a', 'h1', 'b', 'h2', 'c'],
          <String>['c', 'a', 'b'],
        );
        expect(merged, <String>['h2', 'c', 'a', 'h1', 'b']);
      });

      test('trailing hidden ids stay at the end', () {
        final List<String> merged = ProfileGroupData.mergeVisibleOrder(
          <String>['a', 'b', 'h1', 'h2'],
          <String>['b', 'a'],
        );
        expect(merged, <String>['b', 'a', 'h1', 'h2']);
      });

      test('new visible ids are included', () {
        final List<String> merged = ProfileGroupData.mergeVisibleOrder(
          <String>['a', 'b'],
          <String>['a', 'c', 'b'],
        );
        expect(merged, <String>['a', 'c', 'b']);
      });
    });

    group('placeProfiles', () {
      test('into a folder at a position', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b', 'c'],
            ),
            ProfileGroup(uuid: 'g2', name: 'Two', profileIds: <String>['x']),
          ],
          ungrouped: <String>['z'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['z'],
          groupId: 'g1',
          sectionOrder: <String>['a', 'z', 'b', 'c'],
        );
        expect(result.groupById('g1')?.profileIds, <String>[
          'a',
          'z',
          'b',
          'c',
        ]);
        expect(result.groupById('g2')?.profileIds, <String>['x']);
        expect(result.ungrouped, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('into ungrouped', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b'],
            ),
          ],
          ungrouped: <String>['c', 'd'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['b'],
          groupId: null,
          sectionOrder: <String>['c', 'b', 'd'],
        );
        expect(result.groupById('g1')?.profileIds, <String>['a']);
        expect(result.ungrouped, <String>['c', 'b', 'd']);
        _expectNoDuplicateIds(result);
      });

      test('moving between folders', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b'],
            ),
            ProfileGroup(
              uuid: 'g2',
              name: 'Two',
              profileIds: <String>['x', 'y'],
            ),
          ],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['b'],
          groupId: 'g2',
          sectionOrder: <String>['x', 'b', 'y'],
        );
        expect(result.groupById('g1')?.profileIds, <String>['a']);
        expect(result.groupById('g2')?.profileIds, <String>['x', 'b', 'y']);
        _expectNoDuplicateIds(result);
      });

      test('keeps a hidden stored id in place', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              // 'h' is stored but not currently loaded, so the view's
              // sectionOrder below cannot show it.
              profileIds: <String>['a', 'h', 'b'],
            ),
          ],
          ungrouped: <String>['c'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['c'],
          groupId: 'g1',
          sectionOrder: <String>['a', 'c', 'b'],
        );
        expect(result.groupById('g1')?.profileIds, <String>[
          'a',
          'c',
          'h',
          'b',
        ]);
        expect(result.ungrouped, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('ignores an id the view shows in the target that another folder '
          'now holds (stale view)', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            // A concurrent sync already moved 'x' into g1; the dragging
            // view's sectionOrder for g2 below has not caught up.
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'x'],
            ),
            ProfileGroup(uuid: 'g2', name: 'Two', profileIds: <String>['y']),
          ],
          ungrouped: <String>['z'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['z'],
          groupId: 'g2',
          sectionOrder: <String>['y', 'x', 'z'],
        );
        expect(result.groupById('g1')?.profileIds, <String>['a', 'x']);
        expect(result.groupById('g2')?.profileIds, <String>['y', 'z']);
        expect(result.ungrouped, isEmpty);
        _expectNoDuplicateIds(result);
      });

      test('a multi-id move', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(
              uuid: 'g1',
              name: 'One',
              profileIds: <String>['a', 'b', 'c'],
            ),
          ],
          ungrouped: <String>['d', 'e'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['b', 'e'],
          groupId: 'g1',
          sectionOrder: <String>['a', 'e', 'b', 'c'],
        );
        expect(result.groupById('g1')?.profileIds, <String>[
          'a',
          'e',
          'b',
          'c',
        ]);
        expect(result.ungrouped, <String>['d']);
        _expectNoDuplicateIds(result);
      });

      test('an unknown groupId returns the data unchanged', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a']),
          ],
          ungrouped: <String>['b'],
        );
        final ProfileGroupData result = base.placeProfiles(
          profileIds: <String>['a'],
          groupId: 'nope',
          sectionOrder: <String>['a'],
        );
        expect(result, equals(base));
        expect(identical(result, base), isTrue);
      });
    });

    group('withFoldersOrdered', () {
      test('unknown and repeated ids are ignored; unnamed folders are '
          'appended in current order', () {
        const ProfileGroupData base = ProfileGroupData(
          groups: <ProfileGroup>[
            ProfileGroup(uuid: 'g1', name: 'One'),
            ProfileGroup(uuid: 'g2', name: 'Two'),
            ProfileGroup(uuid: 'g3', name: 'Three'),
          ],
        );
        final ProfileGroupData result = base.withFoldersOrdered(<String>[
          'g2',
          'bogus',
          'g2',
          'g1',
        ]);
        expect(result.groups.map((ProfileGroup g) => g.uuid), <String>[
          'g2',
          'g1',
          'g3',
        ]);
      });
    });
  });
}
