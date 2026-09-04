import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/favorite/models/favorite.dart';
import 'package:npt_flutter/features/favorite/repository/favorite_repository.dart';
import 'package:npt_flutter/util/constants.dart';

// Import the existing mocks from ProfileRepository tests
import '../../profile/repository/profile_repository_test.mocks.dart';

void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FavoriteRepository Tests', () {
    late FavoriteRepository repository;
    late MockAtClient mockAtClient;
    late MockAtClientManager mockAtClientManager;

    const testAtsign = '@test_user';
    const testFavoriteProfile = FavoriteProfile(uuid: 'test-profile-uuid-123');
    const testFavoriteProfile2 = FavoriteProfile(uuid: 'test-profile-uuid-456');

    setUp(() {
      mockAtClient = MockAtClient();
      mockAtClientManager = MockAtClientManager();

      // Create repository with injected mock AtClient
      repository = FavoriteRepository(atClient: mockAtClient);

      // Mock AtClientManager singleton behavior
      when(mockAtClientManager.atClient).thenReturn(mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    group('AtKey Generation', () {
      test('should generate correct AtKey for favorites', () {
        final atKey = FavoriteRepository.getFavoriteAtKey();

        expect(atKey.key, equals(Constants.favoriteKeyName));
        expect(atKey.namespace, equals(Constants.namespace));
        expect(atKey.sharedBy, '');
      });

      test('should generate AtKey with sharedBy when provided', () {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        expect(atKey.key, equals(Constants.favoriteKeyName));
        expect(atKey.namespace, equals(Constants.namespace));
        expect(atKey.sharedBy, equals(testAtsign));
      });
    });

    group('getFavorites', () {
      test(
        'should return cached favorites when useCache is true and cache exists',
        () async {
          // First call to populate cache
          final atKey = FavoriteRepository.getFavoriteAtKey(
            sharedBy: testAtsign,
          );
          final favoritesMap = {
            testFavoriteProfile.uuid: testFavoriteProfile.toJson(),
          };
          final atValue = AtValue()..value = jsonEncode(favoritesMap);

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final firstResult = await repository.getFavorites();
          expect(firstResult, isNotNull);
          expect(firstResult!.length, equals(1));
          expect(firstResult[testFavoriteProfile.uuid], isA<FavoriteProfile>());

          // Second call should return cached result without calling AtClient again
          final secondResult = await repository.getFavorites(useCache: true);
          expect(secondResult, equals(firstResult));
          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1); // Should only be called once
        },
      );

      test('should fetch fresh data when useCache is false', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);
        final favoritesMap = {
          testFavoriteProfile.uuid: testFavoriteProfile.toJson(),
        };
        final atValue = AtValue()..value = jsonEncode(favoritesMap);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // First call
        await repository.getFavorites();

        // Second call with useCache false should fetch again
        await repository.getFavorites(useCache: false);

        verify(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(2);
      });

      test(
        'should return empty map when AtClient returns null value',
        () async {
          final atKey = FavoriteRepository.getFavoriteAtKey(
            sharedBy: testAtsign,
          );
          final atValue = AtValue()..value = null;

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getFavorites();

          expect(result, isNotNull);
          expect(result!.isEmpty, isTrue);
          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        },
      );

      test('should parse multiple favorites correctly', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);
        final favoritesMap = {
          testFavoriteProfile.uuid: testFavoriteProfile.toJson(),
          testFavoriteProfile2.uuid: testFavoriteProfile2.toJson(),
        };
        final atValue = AtValue()..value = jsonEncode(favoritesMap);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.length, equals(2));
        expect(result[testFavoriteProfile.uuid], isA<FavoriteProfile>());
        expect(result[testFavoriteProfile2.uuid], isA<FavoriteProfile>());
        expect(
          (result[testFavoriteProfile.uuid] as FavoriteProfile).uuid,
          equals(testFavoriteProfile.uuid),
        );
        expect(
          (result[testFavoriteProfile2.uuid] as FavoriteProfile).uuid,
          equals(testFavoriteProfile2.uuid),
        );
      });

      test('should handle AtClient exceptions gracefully', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(Exception('Network error'));

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
        verify(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle invalid JSON gracefully', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = 'invalid json';

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
        verify(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle non-Map JSON gracefully', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);
        final atValue = AtValue()..value = jsonEncode(['not', 'a', 'map']);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
        verify(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).called(1);
      });

      test('should skip invalid favorite entries', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);
        final favoritesMap = {
          'valid': testFavoriteProfile.toJson(),
          'invalid_string': 'not a map',
          'invalid_object': {'type': 'invalid_type', 'uuid': 'test'},
          'null_favorite': null,
        };
        final atValue = AtValue()..value = jsonEncode(favoritesMap);

        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.length, equals(1));
        expect(result[testFavoriteProfile.uuid], isA<FavoriteProfile>());
      });

      test('should handle null atSign gracefully', () async {
        when(mockAtClient.getCurrentAtSign()).thenReturn(null);

        final result = await repository.getFavorites();

        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
      });
    });

    group('addFavorite', () {
      test('should add favorite to cache and save successfully', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        final result = await repository.addFavorite(testFavoriteProfile);

        expect(result, isTrue);
        verify(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(1);

        // Verify favorite is in cache
        final cachedFavorites = await repository.getFavorites(useCache: true);
        expect(cachedFavorites, isNotNull);
        expect(
          cachedFavorites![testFavoriteProfile.uuid],
          isA<FavoriteProfile>(),
        );
      });

      test('should add multiple favorites correctly', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        await repository.addFavorite(testFavoriteProfile);
        await repository.addFavorite(testFavoriteProfile2);

        final cachedFavorites = await repository.getFavorites(useCache: true);
        expect(cachedFavorites, isNotNull);
        expect(cachedFavorites!.length, equals(2));
        expect(
          cachedFavorites[testFavoriteProfile.uuid],
          isA<FavoriteProfile>(),
        );
        expect(
          cachedFavorites[testFavoriteProfile2.uuid],
          isA<FavoriteProfile>(),
        );
      });

      test('should return false when AtClient put fails', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(Exception('Put failed'));

        final result = await repository.addFavorite(testFavoriteProfile);

        expect(result, isFalse);
        verify(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle null atSign gracefully', () async {
        when(mockAtClient.getCurrentAtSign()).thenReturn(null);

        final result = await repository.addFavorite(testFavoriteProfile);

        expect(result, isFalse);
      });
    });

    group('removeFavorites', () {
      test('should remove single favorite and save successfully', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        // First add a favorite
        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        await repository.addFavorite(testFavoriteProfile);

        // Then remove it
        final result = await repository.removeFavorites([
          testFavoriteProfile.uuid,
        ]);

        expect(result, isTrue);
        verify(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(2); // Once for add, once for remove

        // Verify favorite is removed from cache
        final cachedFavorites = await repository.getFavorites(useCache: true);
        expect(cachedFavorites, isNotNull);
        expect(cachedFavorites!.isEmpty, isTrue);
      });

      test('should remove multiple favorites correctly', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        // Add multiple favorites
        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);
        await repository.addFavorite(testFavoriteProfile);
        await repository.addFavorite(testFavoriteProfile2);

        // Remove both
        final result = await repository.removeFavorites([
          testFavoriteProfile.uuid,
          testFavoriteProfile2.uuid,
        ]);

        expect(result, isTrue);

        // Verify favorites are removed from cache
        final cachedFavorites = await repository.getFavorites(useCache: true);
        expect(cachedFavorites, isNotNull);
        expect(cachedFavorites!.isEmpty, isTrue);
      });

      test(
        'should handle removing non-existent favorites gracefully',
        () async {
          final atKey = FavoriteRepository.getFavoriteAtKey(
            sharedBy: testAtsign,
          );

          when(
            mockAtClient.put(
              atKey,
              any,
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository.removeFavorites([
            'non-existent-uuid',
          ]);

          expect(result, isTrue);
          verify(
            mockAtClient.put(
              atKey,
              any,
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).called(1);
        },
      );

      test('should return false when AtClient put fails', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(Exception('Put failed'));

        final result = await repository.removeFavorites([
          testFavoriteProfile.uuid,
        ]);

        expect(result, isFalse);
        verify(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle empty list of UUIDs', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        final result = await repository.removeFavorites([]);

        expect(result, isTrue);
        verify(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).called(1);
      });

      test('should handle null atSign gracefully', () async {
        when(mockAtClient.getCurrentAtSign()).thenReturn(null);

        final result = await repository.removeFavorites([
          testFavoriteProfile.uuid,
        ]);

        expect(result, isFalse);
      });
    });

    group('Cache Management', () {
      test('should preserve cache state across operations', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        // Add favorite
        await repository.addFavorite(testFavoriteProfile);

        // Remove different favorite (should not affect first one)
        await repository.removeFavorites(['different-uuid']);

        // Check cache still contains first favorite
        final cachedFavorites = await repository.getFavorites(useCache: true);
        expect(cachedFavorites, isNotNull);
        expect(cachedFavorites!.length, equals(1));
        expect(
          cachedFavorites[testFavoriteProfile.uuid],
          isA<FavoriteProfile>(),
        );
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle network and timeout errors gracefully', () async {
        // Test network errors
        when(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(const SocketException('Network error'));

        final getResult = await repository.getFavorites();
        expect(getResult, isNotNull);
        expect(getResult!.isEmpty, isTrue);

        when(
          mockAtClient.put(
            any,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(const SocketException('Network error'));

        final addResult = await repository.addFavorite(testFavoriteProfile);
        expect(addResult, isFalse);

        final removeResult = await repository.removeFavorites([
          testFavoriteProfile.uuid,
        ]);
        expect(removeResult, isFalse);

        // Test timeout errors
        when(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(TimeoutException('Request timeout'));

        final getTimeoutResult = await repository.getFavorites();
        expect(getTimeoutResult, isNotNull);
        expect(getTimeoutResult!.isEmpty, isTrue);

        when(
          mockAtClient.put(
            any,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(TimeoutException('Request timeout'));

        final addTimeoutResult = await repository.addFavorite(
          testFavoriteProfile,
        );
        expect(addTimeoutResult, isFalse);
      });

      test('should handle corrupted server data gracefully', () async {
        // This test simulates a scenario where server data is corrupted
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        // Simulate corruption by setting invalid data on server
        const corruptedData = 'corrupted data';
        final atValue = AtValue()..value = corruptedData;
        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // Getting favorites should handle corruption gracefully and return empty cache
        final result = await repository.getFavorites(useCache: false);
        expect(result, isNotNull);
        expect(result!.isEmpty, isTrue);
      });
    });

    group('Integration Tests', () {
      test('should handle complete workflow: add, get, remove', () async {
        final atKey = FavoriteRepository.getFavoriteAtKey(sharedBy: testAtsign);

        when(
          mockAtClient.put(
            atKey,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        // Initially empty
        when(
          mockAtClient.get(
            atKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => AtValue()..value = null);
        var favorites = await repository.getFavorites();
        expect(favorites!.isEmpty, isTrue);

        // Add favorite
        await repository.addFavorite(testFavoriteProfile);
        favorites = await repository.getFavorites(useCache: true);
        expect(favorites!.length, equals(1));

        // Add another favorite
        await repository.addFavorite(testFavoriteProfile2);
        favorites = await repository.getFavorites(useCache: true);
        expect(favorites!.length, equals(2));

        // Remove one favorite
        await repository.removeFavorites([testFavoriteProfile.uuid]);
        favorites = await repository.getFavorites(useCache: true);
        expect(favorites!.length, equals(1));
        expect(favorites[testFavoriteProfile2.uuid], isNotNull);

        // Remove remaining favorite
        await repository.removeFavorites([testFavoriteProfile2.uuid]);
        favorites = await repository.getFavorites(useCache: true);
        expect(favorites!.isEmpty, isTrue);
      });
    });
  });
}
