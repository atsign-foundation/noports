import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/favorite/models/favorite.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';

void main() {
  group('FavoriteType', () {
    test('should have correct jsonKey values', () {
      expect(FavoriteType.profile.jsonKey, equals('profile'));
    });

    test('fromJsonKey should return correct type for valid key', () {
      expect(FavoriteType.fromJsonKey('profile'), equals(FavoriteType.profile));
    });

    test('fromJsonKey should return null for invalid key', () {
      expect(FavoriteType.fromJsonKey('invalid'), isNull);
      expect(FavoriteType.fromJsonKey(''), isNull);
    });
  });

  group('Favorite.fromJson', () {
    test('should create FavoriteProfile for valid profile JSON', () {
      final json = {
        'type': 'profile',
        'uuid': 'test-uuid-123',
      };

      final result = Favorite.fromJson(json);

      expect(result, isA<FavoriteProfile>());
      expect(result!.uuid, equals('test-uuid-123'));
      expect(result.type, equals(FavoriteType.profile));
    });

    test('should return null for invalid type', () {
      final json = {
        'type': 'invalid',
        'uuid': 'test-uuid-123',
      };

      final result = Favorite.fromJson(json);

      expect(result, isNull);
    });

    test('should handle valid JSON with all required fields', () {
      final json = {
        'type': 'profile',
        'uuid': 'test-uuid-456',
      };

      final result = Favorite.fromJson(json);

      expect(result, isNotNull);
      expect(result, isA<FavoriteProfile>());
      expect(result!.uuid, equals('test-uuid-456'));
    });
  });

  group('FavoriteProfile', () {
    const testUuid = 'test-uuid-123';
    late FavoriteProfile favoriteProfile;

    setUp(() {
      favoriteProfile = const FavoriteProfile(uuid: testUuid);
    });

    test('should create instance with correct values', () {
      expect(favoriteProfile.uuid, equals(testUuid));
      expect(favoriteProfile.type, equals(FavoriteType.profile));
    });

    test('should implement toString correctly', () {
      final result = favoriteProfile.toString();
      expect(result, equals('FavoriteProfile(uuid: $testUuid)'));
    });

    test('should serialize to JSON correctly', () {
      final json = favoriteProfile.toJson();

      expect(json['uuid'], equals(testUuid));
      expect(json['type'], equals('profile'));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'uuid': testUuid,
        'type': 'profile',
      };

      final result = FavoriteProfile.fromJson(json);

      expect(result.uuid, equals(testUuid));
      expect(result.type, equals(FavoriteType.profile));
    });

    test('should have correct profileIds', () {
      expect(favoriteProfile.profileIds, equals([testUuid]));
    });

    test('containsProfile should return true for matching uuid', () {
      expect(favoriteProfile.containsProfile(testUuid), isTrue);
    });

    test('containsProfile should return false for non-matching uuid', () {
      expect(favoriteProfile.containsProfile('different-uuid'), isFalse);
    });

    test('isLoadedInProfiles should return true when uuid is in list', () {
      final profiles = [testUuid, 'other-uuid'];
      expect(favoriteProfile.isLoadedInProfiles(profiles), isTrue);
    });

    test('isLoadedInProfiles should return false when uuid is not in list', () {
      final profiles = ['other-uuid', 'another-uuid'];
      expect(favoriteProfile.isLoadedInProfiles(profiles), isFalse);
    });

    test('isFavoriteMatch should return true for matching Profile', () {
      const profile = Profile(
        testUuid,
        displayName: 'Test Profile',
        sshnpdAtsign: '@test_device',
        deviceName: 'test-device',
        remotePort: 22,
        localPort: 2222,
      );

      expect(favoriteProfile.isFavoriteMatch(profile), isTrue);
    });

    test('isFavoriteMatch should return false for non-matching Profile', () {
      const profile = Profile(
        'different-uuid',
        displayName: 'Test Profile',
        sshnpdAtsign: '@test_device',
        deviceName: 'test-device',
        remotePort: 22,
        localPort: 2222,
      );

      expect(favoriteProfile.isFavoriteMatch(profile), isFalse);
    });

    test('equality should work correctly', () {
      const favorite1 = FavoriteProfile(uuid: testUuid);
      const favorite2 = FavoriteProfile(uuid: testUuid);
      const favorite3 = FavoriteProfile(uuid: 'different-uuid');

      expect(favorite1, equals(favorite2));
      expect(favorite1, isNot(equals(favorite3)));
    });

    test('JSON round-trip should preserve data', () {
      final json = favoriteProfile.toJson();
      final restored = FavoriteProfile.fromJson(json);

      expect(restored.uuid, equals(favoriteProfile.uuid));
      expect(restored.type, equals(favoriteProfile.type));
      expect(restored, equals(favoriteProfile));
    });
  });

  group('Favorite base class toJson', () {
    test('should include type in JSON', () {
      const favoriteProfile = FavoriteProfile(uuid: 'test-uuid');
      final json = favoriteProfile.toJson();

      expect(json.containsKey('type'), isTrue);
      expect(json['type'], equals('profile'));
    });
  });
}
