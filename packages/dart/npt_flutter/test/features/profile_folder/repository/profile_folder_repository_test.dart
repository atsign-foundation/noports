import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/features/profile_folder/repository/profile_folder_repository.dart';
import 'package:npt_flutter/util/constants.dart';

import '../../profile/repository/profile_repository_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileFolderRepository', () {
    late ProfileFolderRepository repository;
    late MockAtClient mockAtClient;

    const String testAtsign = '@test_user';
    const ProfileFolderData testData = ProfileFolderData(
      folders: <ProfileFolder>[
        ProfileFolder(uuid: 'g1', name: 'One', profileIds: <String>['a', 'b']),
      ],
    );

    setUp(() {
      mockAtClient = MockAtClient();
      repository = ProfileFolderRepository(atClient: mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    AtKey expectedKey() =>
        ProfileFolderRepository.getProfileFolderAtKey(sharedBy: testAtsign);

    test('builds a self key in the noports namespace', () {
      final AtKey key = ProfileFolderRepository.getProfileFolderAtKey();
      expect(key.key, Constants.profileFolderKeyName);
      expect(key.namespace, Constants.namespace);
      expect(key.sharedBy, '');

      final AtKey shared = expectedKey();
      expect(shared.sharedBy, testAtsign);
    });

    group('getProfileFolders', () {
      test('parses stored json', () async {
        final AtValue value = AtValue()..value = jsonEncode(testData.toJson());
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(testData));
      });

      test('returns empty data when the value is null', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenAnswer((_) async => AtValue());

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(const ProfileFolderData()));
      });

      test('returns empty data when the key does not exist yet', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(AtKeyNotFoundException('missing'));

        final ProfileFolderData? result = await repository.getProfileFolders();

        expect(result, equals(const ProfileFolderData()));
      });

      test('returns null when the value is not a map', () async {
        final AtValue value = AtValue()..value = jsonEncode(<int>[1, 2, 3]);
        when(mockAtClient.get(expectedKey())).thenAnswer((_) async => value);

        expect(await repository.getProfileFolders(), isNull);
      });

      test('returns null on other failures', () async {
        when(
          mockAtClient.get(expectedKey()),
        ).thenThrow(Exception('network down'));

        expect(await repository.getProfileFolders(), isNull);
      });
    });

    group('putProfileFolders', () {
      test('writes the encoded json and returns the client result', () async {
        when(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).thenAnswer((_) async => true);

        expect(await repository.putProfileFolders(testData), isTrue);
        verify(
          mockAtClient.put(expectedKey(), jsonEncode(testData.toJson())),
        ).called(1);
      });

      test('returns false when the client throws', () async {
        when(mockAtClient.put(any, any)).thenThrow(Exception('write failed'));

        expect(await repository.putProfileFolders(testData), isFalse);
      });
    });

    group('waitForSync', () {
      test('is false when the sync service throws', () async {
        when(mockAtClient.syncService).thenThrow(StateError('no client'));

        expect(await repository.waitForSync(), isFalse);
      });
    });
  });
}
