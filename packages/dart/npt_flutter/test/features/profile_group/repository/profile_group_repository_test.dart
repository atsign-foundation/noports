import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/features/profile_group/repository/profile_group_repository.dart';
import 'package:npt_flutter/util/constants.dart';

import '../../profile/repository/profile_repository_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileGroupRepository', () {
    late ProfileGroupRepository repository;
    late MockAtClient mockAtClient;

    const String testAtsign = '@test_user';
    const ProfileGroupData testData = ProfileGroupData(
      groups: <ProfileGroup>[
        ProfileGroup(uuid: 'g1', name: 'One', profileIds: <String>['a', 'b']),
      ],
      sortByType: true,
    );

    setUp(() {
      mockAtClient = MockAtClient();
      repository = ProfileGroupRepository(atClient: mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    AtKey expectedKey() =>
        ProfileGroupRepository.getProfileGroupAtKey(sharedBy: testAtsign);

    test('builds a self key in the noports namespace', () {
      final AtKey key = ProfileGroupRepository.getProfileGroupAtKey();
      expect(key.key, Constants.profileGroupKeyName);
      expect(key.namespace, Constants.namespace);
      expect(key.sharedBy, '');

      final AtKey shared = expectedKey();
      expect(shared.sharedBy, testAtsign);
    });

    group('getProfileGroups', () {
      test('parses stored json', () async {
        final AtValue value = AtValue()..value = jsonEncode(testData.toJson());
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        final ProfileGroupData? result = await repository.getProfileGroups();

        expect(result, equals(testData));
      });

      test('returns empty data when the value is null', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenAnswer((_) async => AtValue());

        final ProfileGroupData? result = await repository.getProfileGroups();

        expect(result, equals(const ProfileGroupData()));
      });

      test('returns empty data when the key does not exist yet', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(AtKeyNotFoundException('missing'));

        final ProfileGroupData? result = await repository.getProfileGroups();

        expect(result, equals(const ProfileGroupData()));
      });

      test('returns null when the value is not a map', () async {
        final AtValue value = AtValue()..value = jsonEncode(<int>[1, 2, 3]);
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        expect(await repository.getProfileGroups(), isNull);
      });

      test('returns null on other failures', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(Exception('network down'));

        expect(await repository.getProfileGroups(), isNull);
      });
    });

    group('putProfileGroups', () {
      test('writes the encoded json and returns the client result', () async {
        when(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).thenAnswer((_) async => true);

        expect(await repository.putProfileGroups(testData), isTrue);
        verify(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).called(1);
      });

      test('returns false when the client throws', () async {
        when(mockAtClient.put(any, any)).thenThrow(Exception('write failed'));

        expect(await repository.putProfileGroups(testData), isFalse);
      });
    });
  });
}
