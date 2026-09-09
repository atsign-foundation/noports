import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';

void main() {
  group('ProfileType', () {
    test('fromProtocol maps known protocols', () {
      expect(ProfileType.fromProtocol('ssh'), ProfileType.ssh);
      expect(ProfileType.fromProtocol('SSH'), ProfileType.ssh);
      expect(ProfileType.fromProtocol('rdp'), ProfileType.rdp);
      expect(ProfileType.fromProtocol('http'), ProfileType.http);
      expect(ProfileType.fromProtocol('https'), ProfileType.http);
      expect(ProfileType.fromProtocol('vnc'), ProfileType.vnc);
    });

    test('fromProtocol falls back to none', () {
      expect(ProfileType.fromProtocol(null), ProfileType.none);
      expect(ProfileType.fromProtocol(''), ProfileType.none);
      expect(ProfileType.fromProtocol('ftp'), ProfileType.none);
    });

    Profile buildProfile({String? protocol, String? connectUri}) {
      return Profile(
        'uuid',
        displayName: 'name',
        deviceName: 'device',
        remotePort: 22,
        localPort: 2222,
        connectUriProtocol: protocol,
        connectUri: connectUri,
      );
    }

    test('fromProfile prefers connectUriProtocol', () {
      expect(
        ProfileType.fromProfile(
          buildProfile(protocol: 'rdp', connectUri: 'ssh://localhost:22'),
        ),
        ProfileType.rdp,
      );
    });

    test('fromProfile treats an explicit empty protocol as none', () {
      expect(
        ProfileType.fromProfile(
          buildProfile(protocol: '', connectUri: 'ssh://localhost:22'),
        ),
        ProfileType.none,
      );
    });

    test('fromProfile parses a legacy connectUri scheme', () {
      expect(
        ProfileType.fromProfile(
          buildProfile(connectUri: 'vnc://user@localhost:5900'),
        ),
        ProfileType.vnc,
      );
      expect(
        ProfileType.fromProfile(buildProfile(connectUri: 'garbage')),
        ProfileType.none,
      );
      expect(ProfileType.fromProfile(buildProfile()), ProfileType.none);
    });
  });

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
      sortByType: true,
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
      expect(parsed.sortByType, isFalse);
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
      expect(parsed.sortByType, isFalse);
    });

    test('groupForProfile and groupById', () {
      expect(data.groupForProfile('c')?.uuid, 'g2');
      expect(data.groupForProfile('zzz'), isNull);
      expect(data.groupById('g1')?.name, 'One');
      expect(data.groupById('nope'), isNull);
    });
  });
}
