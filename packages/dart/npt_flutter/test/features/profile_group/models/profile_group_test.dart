import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';

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

    test('fromJson drops groups without a uuid and non-map entries', () {
      final ProfileGroupData parsed = ProfileGroupData.fromJson(
        <String, dynamic>{
          'groups': <dynamic>[
            <String, dynamic>{'name': 'no uuid'},
            'junk',
            <String, dynamic>{'uuid': 'ok', 'name': 'Ok'},
          ],
          'sortByType': 'yes',
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
  });
}
