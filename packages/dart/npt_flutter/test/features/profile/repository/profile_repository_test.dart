import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';
import 'package:npt_flutter/features/profile/repository/profile_repository.dart';
import 'package:npt_flutter/util/uuid.dart';

import 'profile_repository_test.mocks.dart';

@GenerateMocks([AtClient, AtClientManager])
void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ProfileRepository Tests', () {
    late ProfileRepository repository;
    late MockAtClient mockAtClient;
    late MockAtClientManager mockAtClientManager;

    const testUuid = 'test-uuid-123';
    const testAtsign = '@test_user';
    final testProfile = Profile(
      testUuid,
      displayName: 'Test Profile',
      sshnpdAtsign: '@test_device'.toAtsign(),
      deviceName: 'test-device',
      remotePort: 22,
      localPort: 2222,
      relayAtsign: '@relay_test'.toAtsign(),
    );

    setUp(() {
      mockAtClient = MockAtClient();
      mockAtClientManager = MockAtClientManager();

      // Create repository with injected mock AtClient
      repository = ProfileRepository(atClient: mockAtClient);

      // Mock AtClientManager singleton behavior
      when(mockAtClientManager.atClient).thenReturn(mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    group('Cache Functionality', () {
      test('should initialize with empty cache', () {
        expect(repository, isNotNull);
      });

      test('should cache profiles after retrieval', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = jsonEncode(testProfile.toJson());

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // First call - should hit AtClient
        final firstResult = await repository.getProfile(testUuid);
        expect(firstResult, isNotNull);
        expect(firstResult!.uuid, equals(testUuid));

        // Second call - should use cache
        final secondResult = await repository.getProfile(
          testUuid,
          useCache: true,
        );
        expect(secondResult, isNotNull);
        expect(secondResult!.uuid, equals(testUuid));

        // Verify AtClient was only called once
        verify(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should bypass cache when useCache is false', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = jsonEncode(testProfile.toJson());

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // First call
        await repository.getProfile(testUuid, useCache: false);

        // Second call with useCache false - should hit AtClient again
        final result = await repository.getProfile(testUuid, useCache: false);

        expect(result, isNotNull);
        expect(result!.uuid, equals(testUuid));

        // Verify AtClient was called twice
        verify(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(2);
      });

      test('should update cache when putProfile is called', () async {
        final updatedProfile = Profile(
          testUuid,
          displayName: 'Updated Profile',
          sshnpdAtsign: '@updated_device'.toAtsign(),
          deviceName: 'updated-device',
          remotePort: 23,
          localPort: 2223,
        );

        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);

        // Put original profile
        when(
          mockAtClient.put(
            atKey,
            jsonEncode(testProfile.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        await repository.putProfile(testProfile);

        // Put updated profile
        when(
          mockAtClient.put(
            atKey,
            jsonEncode(updatedProfile.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        await repository.putProfile(updatedProfile);

        // Get profile - should return updated version from cache
        final result = await repository.getProfile(testUuid, useCache: true);
        expect(result, isNotNull);
        expect(result!.displayName, equals('Updated Profile'));
        expect(result.sshnpdAtsign, equals('@updated_device'.toAtsign()));

        // Should not have called get on AtClient since it's cached
        verifyNever(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        );
      });

      test('should remove from cache when deleteProfile is called', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);

        // First, put a profile in cache
        when(
          mockAtClient.put(
            atKey,
            jsonEncode(testProfile.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        await repository.putProfile(testProfile);

        // Then delete it
        when(
          mockAtClient.delete(
            atKey,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        final deleteResult = await repository.deleteProfile(testUuid);
        expect(deleteResult, isTrue);

        // Verify profile is removed from cache by checking it tries to fetch from AtClient
        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(Exception('Not found'));
        final cachedProfile = await repository.getProfile(
          testUuid,
          useCache: true,
        );
        expect(cachedProfile, isNull);

        verify(
          mockAtClient.delete(
            atKey,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).called(1);
      });
    });

    group('CRUD Operations', () {
      group('getProfile', () {
        test('should return profile from AtClient when not cached', () async {
          final atKey = const Uuid(
            testUuid,
          ).toProfileAtKey(sharedBy: testAtsign);
          final atValue = AtValue()..value = jsonEncode(testProfile.toJson());

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getProfile(testUuid);

          expect(result, isNotNull);
          expect(result!.uuid, equals(testUuid));
          expect(result.displayName, equals('Test Profile'));
          expect(result.sshnpdAtsign, equals('@test_device'));
          expect(result.deviceName, equals('test-device'));
          verify(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should return null when AtClient throws exception', () async {
          final atKey = const Uuid(
            testUuid,
          ).toProfileAtKey(sharedBy: testAtsign);

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenThrow(Exception('Profile not found'));

          final result = await repository.getProfile(testUuid);

          expect(result, isNull);
          verify(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle JSON decode errors gracefully', () async {
          final atKey = const Uuid(
            testUuid,
          ).toProfileAtKey(sharedBy: testAtsign);
          final atValue = AtValue()..value = 'invalid json';

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getProfile(testUuid);

          expect(result, isNull);
          verify(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle null atSign gracefully', () async {
          when(mockAtClient.getCurrentAtSign()).thenReturn(null);

          final result = await repository.getProfile(testUuid);

          expect(result, isNull);
        });
      });

      group('putProfile', () {
        test(
          'should successfully save profile to AtClient and cache',
          () async {
            final atKey = Uuid(
              testProfile.uuid,
            ).toProfileAtKey(sharedBy: testAtsign);

            when(
              mockAtClient.put(
                atKey,
                jsonEncode(testProfile.toJson()),
                putRequestOptions: anyNamed('putRequestOptions'),
              ),
            ).thenAnswer((_) async => true);

            final result = await repository.putProfile(testProfile);

            expect(result, isTrue);
            verify(
              mockAtClient.put(
                atKey,
                jsonEncode(testProfile.toJson()),
                putRequestOptions: anyNamed('putRequestOptions'),
              ),
            ).called(1);

            // Verify profile is cached
            final cachedProfile = await repository.getProfile(
              testProfile.uuid,
              useCache: true,
            );
            expect(cachedProfile, equals(testProfile));
          },
        );

        test('should return false when AtClient put fails', () async {
          final atKey = Uuid(
            testProfile.uuid,
          ).toProfileAtKey(sharedBy: testAtsign);

          when(
            mockAtClient.put(
              atKey,
              jsonEncode(testProfile.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenThrow(Exception('Put failed'));

          final result = await repository.putProfile(testProfile);

          expect(result, isFalse);
          verify(
            mockAtClient.put(
              atKey,
              jsonEncode(testProfile.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).called(1);
        });

        test('should update cache even when AtClient fails', () async {
          final atKey = Uuid(
            testProfile.uuid,
          ).toProfileAtKey(sharedBy: testAtsign);

          when(
            mockAtClient.put(
              atKey,
              jsonEncode(testProfile.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenThrow(Exception('Put failed'));

          await repository.putProfile(testProfile);

          // Profile should still be in cache
          final cachedProfile = await repository.getProfile(
            testProfile.uuid,
            useCache: true,
          );
          expect(cachedProfile, equals(testProfile));
        });

        test('should handle null atSign gracefully', () async {
          when(mockAtClient.getCurrentAtSign()).thenReturn(null);

          final result = await repository.putProfile(testProfile);

          expect(result, isFalse);
        });
      });

      group('deleteProfile', () {
        test(
          'should successfully delete profile from AtClient and cache',
          () async {
            final atKey = const Uuid(
              testUuid,
            ).toProfileAtKey(sharedBy: testAtsign);

            // First, put a profile in cache
            when(
              mockAtClient.put(
                atKey,
                jsonEncode(testProfile.toJson()),
                putRequestOptions: anyNamed('putRequestOptions'),
              ),
            ).thenAnswer((_) async => true);
            await repository.putProfile(testProfile);

            // Then delete it
            when(
              mockAtClient.delete(
                atKey,
                deleteRequestOptions: anyNamed('deleteRequestOptions'),
              ),
            ).thenAnswer((_) async => true);

            final result = await repository.deleteProfile(testUuid);

            expect(result, isTrue);
            verify(
              mockAtClient.delete(
                atKey,
                deleteRequestOptions: anyNamed('deleteRequestOptions'),
              ),
            ).called(1);

            // Verify profile is removed from cache
            when(
              mockAtClient.get(
                atKey,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenThrow(Exception('Not found'));
            final cachedProfile = await repository.getProfile(
              testUuid,
              useCache: true,
            );
            expect(cachedProfile, isNull);
          },
        );

        test('should return false when AtClient delete fails', () async {
          final atKey = const Uuid(
            testUuid,
          ).toProfileAtKey(sharedBy: testAtsign);

          when(
            mockAtClient.delete(
              atKey,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).thenThrow(Exception('Delete failed'));

          final result = await repository.deleteProfile(testUuid);

          expect(result, isFalse);
          verify(
            mockAtClient.delete(
              atKey,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).called(1);
        });

        test(
          'should remove from cache even when AtClient delete fails',
          () async {
            final atKey = const Uuid(
              testUuid,
            ).toProfileAtKey(sharedBy: testAtsign);

            // First, put a profile in cache
            when(
              mockAtClient.put(
                atKey,
                jsonEncode(testProfile.toJson()),
                putRequestOptions: anyNamed('putRequestOptions'),
              ),
            ).thenAnswer((_) async => true);
            await repository.putProfile(testProfile);

            // Mock delete failure
            when(
              mockAtClient.delete(
                atKey,
                deleteRequestOptions: anyNamed('deleteRequestOptions'),
              ),
            ).thenThrow(Exception('Delete failed'));

            await repository.deleteProfile(testUuid);

            // Profile should still be removed from cache
            when(
              mockAtClient.get(
                atKey,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenThrow(Exception('Not found'));
            final cachedProfile = await repository.getProfile(
              testUuid,
              useCache: true,
            );
            expect(cachedProfile, isNull);
          },
        );

        test('should handle null atSign gracefully', () async {
          when(mockAtClient.getCurrentAtSign()).thenReturn(null);

          final result = await repository.deleteProfile(testUuid);

          expect(result, isFalse);
        });
      });

      group('getProfiles', () {
        test('should return multiple profiles for given UUIDs', () async {
          const uuids = ['uuid1', 'uuid2', 'uuid3'];
          final profiles = [
            Profile(
              'uuid1',
              displayName: 'Profile 1',
              sshnpdAtsign: '@device1'.toAtsign(),
              deviceName: 'device1',
              remotePort: 22,
              localPort: 2222,
            ),
            Profile(
              'uuid2',
              displayName: 'Profile 2',
              sshnpdAtsign: '@device2'.toAtsign(),
              deviceName: 'device2',
              remotePort: 23,
              localPort: 2223,
            ),
            Profile(
              'uuid3',
              displayName: 'Profile 3',
              sshnpdAtsign: '@device3'.toAtsign(),
              deviceName: 'device3',
              remotePort: 24,
              localPort: 2224,
            ),
          ];

          // Mock individual getProfile calls
          for (int i = 0; i < uuids.length; i++) {
            final uuid = uuids[i];
            final profile = profiles[i];
            final atKey = Uuid(uuid).toProfileAtKey(sharedBy: testAtsign);

            when(
              mockAtClient.get(
                atKey,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenAnswer(
              (_) async => AtValue()..value = jsonEncode(profile.toJson()),
            );
          }

          final result = await repository.getProfiles(uuids);

          expect(result, hasLength(3));
          expect(result.map((p) => p.uuid).toList(), equals(uuids));
          expect(
            result.map((p) => p.displayName).toList(),
            equals(['Profile 1', 'Profile 2', 'Profile 3']),
          );
        });

        test(
          'should filter out null profiles when some fail to load',
          () async {
            const uuids = ['uuid1', 'uuid2', 'uuid3'];
            final successProfile = Profile(
              'uuid1',
              displayName: 'Profile 1',
              sshnpdAtsign: '@device1'.toAtsign(),
              deviceName: 'device1',
              remotePort: 22,
              localPort: 2222,
            );

            // Mock successful call for uuid1
            final atKey1 = const Uuid(
              'uuid1',
            ).toProfileAtKey(sharedBy: testAtsign);
            when(
              mockAtClient.get(
                atKey1,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenAnswer(
              (_) async =>
                  AtValue()..value = jsonEncode(successProfile.toJson()),
            );

            // Mock failed calls for uuid2 and uuid3
            final atKey2 = const Uuid(
              'uuid2',
            ).toProfileAtKey(sharedBy: testAtsign);
            final atKey3 = const Uuid(
              'uuid3',
            ).toProfileAtKey(sharedBy: testAtsign);
            when(
              mockAtClient.get(
                atKey2,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenThrow(Exception('Not found'));
            when(
              mockAtClient.get(
                atKey3,
                getRequestOptions: anyNamed('getRequestOptions'),
              ),
            ).thenThrow(Exception('Not found'));

            final result = await repository.getProfiles(uuids);

            expect(result, hasLength(1));
            expect(result.first.uuid, equals('uuid1'));
            expect(result.first.displayName, equals('Profile 1'));
          },
        );

        test(
          'should return empty iterable when all profiles fail to load',
          () async {
            const uuids = ['uuid1', 'uuid2'];

            for (final uuid in uuids) {
              final atKey = Uuid(uuid).toProfileAtKey(sharedBy: testAtsign);
              when(
                mockAtClient.get(
                  atKey,
                  getRequestOptions: anyNamed('getRequestOptions'),
                ),
              ).thenThrow(Exception('Not found'));
            }

            final result = await repository.getProfiles(uuids);

            expect(result, isEmpty);
          },
        );

        test('should handle empty UUID list', () async {
          const emptyUuids = <String>[];
          final profiles = await repository.getProfiles(emptyUuids);

          expect(profiles, isEmpty);
        });

        test('should use cached profiles when available', () async {
          const uuids = ['uuid1', 'uuid2'];
          final profile1 = Profile(
            'uuid1',
            displayName: 'Profile 1',
            sshnpdAtsign: '@device1'.toAtsign(),
            deviceName: 'device1',
            remotePort: 22,
            localPort: 2222,
          );
          final profile2 = Profile(
            'uuid2',
            displayName: 'Profile 2',
            sshnpdAtsign: '@device2'.toAtsign(),
            deviceName: 'device2',
            remotePort: 23,
            localPort: 2223,
          );

          // Pre-cache profile1
          final atKey1 = const Uuid(
            'uuid1',
          ).toProfileAtKey(sharedBy: testAtsign);
          when(
            mockAtClient.put(
              atKey1,
              jsonEncode(profile1.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenAnswer((_) async => true);
          await repository.putProfile(profile1);

          // Mock AtClient call for profile2
          final atKey2 = const Uuid(
            'uuid2',
          ).toProfileAtKey(sharedBy: testAtsign);
          when(
            mockAtClient.get(
              atKey2,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer(
            (_) async => AtValue()..value = jsonEncode(profile2.toJson()),
          );

          final result = await repository.getProfiles(uuids);

          expect(result, hasLength(2));
          expect(result.map((p) => p.uuid).toList(), equals(uuids));

          // Verify profile1 was not fetched from AtClient (cached)
          verifyNever(
            mockAtClient.get(
              atKey1,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          );
          // Verify profile2 was fetched from AtClient
          verify(
            mockAtClient.get(
              atKey2,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });
      });

      group('getProfileUuids', () {
        test('should return profile UUIDs from AtClient', () async {
          final mockKeys = [
            'uuid1.profiles.noports$testAtsign',
            'uuid2.profiles.noports$testAtsign',
            'uuid3.profiles.noports$testAtsign',
          ];

          when(
            mockAtClient.getKeys(
              regex: '.profiles.noports',
              useRemoteAtServer: true,
            ),
          ).thenAnswer((_) async => mockKeys);

          final result = await repository.getProfileUuids();

          expect(result, isNotNull);
          expect(result, hasLength(3));
          expect(result!.toList(), equals(['uuid1', 'uuid2', 'uuid3']));
        });

        test(
          'should return empty list when AtClient throws exception',
          () async {
            when(
              mockAtClient.getKeys(
                regex: '.profiles.noports',
                useRemoteAtServer: true,
              ),
            ).thenThrow(Exception('Failed to get keys'));

            final result = await repository.getProfileUuids();

            expect(result, isNotNull);
            expect(result, isEmpty);
          },
        );

        test('should handle empty key list', () async {
          when(
            mockAtClient.getKeys(
              regex: '.profiles.noports',
              useRemoteAtServer: true,
            ),
          ).thenAnswer((_) async => <String>[]);

          final result = await repository.getProfileUuids();

          expect(result, isNotNull);
          expect(result, isEmpty);
        });
      });
    });

    group('AtKey Generation and Namespacing', () {
      test('should generate correct AtKey for profile operations', () async {
        final expectedAtKey = const Uuid(
          testUuid,
        ).toProfileAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.get(
            expectedAtKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer(
          (_) async => AtValue()..value = jsonEncode(testProfile.toJson()),
        );

        await repository.getProfile(testUuid);

        verify(
          mockAtClient.get(
            expectedAtKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should use consistent AtKey format across operations', () async {
        final atKey = Uuid(
          testProfile.uuid,
        ).toProfileAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            jsonEncode(testProfile.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer(
          (_) async => AtValue()..value = jsonEncode(testProfile.toJson()),
        );
        when(
          mockAtClient.delete(
            atKey,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        // Test put
        await repository.putProfile(testProfile);
        verify(
          mockAtClient.put(
            atKey,
            jsonEncode(testProfile.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(1);

        // Test get
        await repository.getProfile(testProfile.uuid, useCache: false);
        verify(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);

        // Test delete
        await repository.deleteProfile(testProfile.uuid);
        verify(
          mockAtClient.delete(
            atKey,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).called(1);
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle null values gracefully', () async {
        when(mockAtClient.getCurrentAtSign()).thenReturn(null);

        final getResult = await repository.getProfile(testUuid);
        expect(getResult, isNull);

        final putResult = await repository.putProfile(testProfile);
        expect(putResult, isFalse);

        final deleteResult = await repository.deleteProfile(testUuid);
        expect(deleteResult, isFalse);
      });

      test('should handle AtClient network errors gracefully', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(Exception('Network error'));
        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(Exception('Network error'));
        when(
          mockAtClient.delete(
            atKey,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).thenThrow(Exception('Network error'));

        // Should not throw, should return null/false
        final getResult = await repository.getProfile(testUuid);
        expect(getResult, isNull);

        final putResult = await repository.putProfile(testProfile);
        expect(putResult, isFalse);

        final deleteResult = await repository.deleteProfile(testUuid);
        expect(deleteResult, isFalse);
      });

      test('should handle malformed JSON in AtClient response', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = '{invalid json}';

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        final result = await repository.getProfile(testUuid);

        expect(result, isNull);
        verify(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle concurrent operations correctly', () async {
        final atKey = const Uuid(testUuid).toProfileAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = jsonEncode(testProfile.toJson());

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // Simulate concurrent gets
        final futures = List.generate(
          5,
          (_) => repository.getProfile(testUuid, useCache: false),
        );
        final results = await Future.wait(futures);

        for (final result in results) {
          expect(result, isNotNull);
          expect(result!.uuid, equals(testUuid));
        }

        // Should have called AtClient 5 times since useCache is false
        verify(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(5);
      });
    });
  });
}
