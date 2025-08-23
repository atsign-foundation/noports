import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/favorite/models/favoritable.dart';
import 'package:npt_flutter/features/profile/models/profile.dart';

void main() {
  group('Profile Model Tests', () {
    const testUuid = 'test-uuid-123';
    const testDisplayName = 'Test Profile';
    const testSshnpdAtsign = '@test_device';
    const testDeviceName = 'test-device';
    const testRemoteHost = 'localhost';
    const testRemotePort = 22;
    const testLocalPort = 2222;
    const testRelayAtsign = '@relay_test';

    late Profile testProfile;

    setUp(() {
      testProfile = const Profile(
        testUuid,
        displayName: testDisplayName,
        sshnpdAtsign: testSshnpdAtsign,
        deviceName: testDeviceName,
        remoteHost: testRemoteHost,
        remotePort: testRemotePort,
        localPort: testLocalPort,
        relayAtsign: testRelayAtsign,
      );
    });

    group('Profile Creation', () {
      test('should create profile with all fields', () {
        expect(testProfile.uuid, equals(testUuid));
        expect(testProfile.displayName, equals(testDisplayName));
        expect(testProfile.sshnpdAtsign, equals(testSshnpdAtsign));
        expect(testProfile.deviceName, equals(testDeviceName));
        expect(testProfile.remoteHost, equals(testRemoteHost));
        expect(testProfile.remotePort, equals(testRemotePort));
        expect(testProfile.localPort, equals(testLocalPort));
        expect(testProfile.relayAtsign, equals(testRelayAtsign));
      });

      test(
        'should create profile with default remoteHost when not provided',
        () {
          const profileWithoutRemoteHost = Profile(
            testUuid,
            displayName: testDisplayName,
            sshnpdAtsign: testSshnpdAtsign,
            deviceName: testDeviceName,
            remotePort: testRemotePort,
            localPort: testLocalPort,
          );

          expect(profileWithoutRemoteHost.remoteHost, equals('localhost'));
        },
      );

      test('should create profile with null relayAtsign', () {
        const profileWithoutRelay = Profile(
          testUuid,
          displayName: testDisplayName,
          sshnpdAtsign: testSshnpdAtsign,
          deviceName: testDeviceName,
          remotePort: testRemotePort,
          localPort: testLocalPort,
        );

        expect(profileWithoutRelay.relayAtsign, isNull);
      });
    });

    group('Profile copyWith', () {
      test('should copy profile with updated displayName', () {
        const newDisplayName = 'Updated Profile Name';
        final updatedProfile = testProfile.copyWith(
          displayName: newDisplayName,
        );

        expect(updatedProfile.displayName, equals(newDisplayName));
        expect(updatedProfile.uuid, equals(testProfile.uuid));
        expect(updatedProfile.sshnpdAtsign, equals(testProfile.sshnpdAtsign));
        expect(updatedProfile.deviceName, equals(testProfile.deviceName));
      });

      test('should copy profile with updated uuid', () {
        const newUuid = 'new-uuid-456';
        final updatedProfile = testProfile.copyWith(uuid: newUuid);

        expect(updatedProfile.uuid, equals(newUuid));
        expect(updatedProfile.displayName, equals(testProfile.displayName));
      });

      test('should copy profile with updated ports', () {
        const newRemotePort = 80;
        const newLocalPort = 8080;
        final updatedProfile = testProfile.copyWith(
          remotePort: newRemotePort,
          localPort: newLocalPort,
        );

        expect(updatedProfile.remotePort, equals(newRemotePort));
        expect(updatedProfile.localPort, equals(newLocalPort));
        expect(updatedProfile.uuid, equals(testProfile.uuid));
      });

      test('should copy profile with updated relayAtsign', () {
        const newRelayAtsign = '@new_relay';
        final updatedProfile = testProfile.copyWith(
          relayAtsign: newRelayAtsign,
        );

        expect(updatedProfile.relayAtsign, equals(newRelayAtsign));
        expect(updatedProfile.uuid, equals(testProfile.uuid));
      });

      test('should not modify original profile when copying', () {
        const newDisplayName = 'Updated Profile Name';
        testProfile.copyWith(displayName: newDisplayName);

        // Original profile should remain unchanged
        expect(testProfile.displayName, equals(testDisplayName));
      });
    });

    group('Profile JSON Serialization', () {
      test(
        'should handle JSON serialization and deserialization correctly',
        () {
          // Test standard JSON serialization
          final json = testProfile.toJson();
          expect(json['uuid'], equals(testUuid));
          expect(json['displayName'], equals(testDisplayName));
          expect(json['sshnpdAtsign'], equals(testSshnpdAtsign));
          expect(json['deviceName'], equals(testDeviceName));
          expect(json['remoteHost'], equals(testRemoteHost));
          expect(json['remotePort'], equals(testRemotePort));
          expect(json['localPort'], equals(testLocalPort));
          expect(json['relayAtsign'], equals(testRelayAtsign));

          // Test exportable JSON (without UUID)
          final exportableJson = testProfile.toExportableJson();
          expect(exportableJson.containsKey('uuid'), isFalse);
          expect(exportableJson['displayName'], equals(testDisplayName));
          expect(exportableJson['sshnpdAtsign'], equals(testSshnpdAtsign));
          expect(exportableJson['deviceName'], equals(testDeviceName));

          // Test deserialization from complete JSON
          final deserializedProfile = Profile.fromJson(json);
          expect(deserializedProfile, equals(testProfile));

          // Test deserialization with default remoteHost
          final jsonWithoutHost = {
            'displayName': testDisplayName,
            'sshnpdAtsign': testSshnpdAtsign,
            'deviceName': testDeviceName,
            'remotePort': testRemotePort,
            'localPort': testLocalPort,
          };
          final profileWithDefaultHost = Profile.fromJson(jsonWithoutHost);
          expect(profileWithDefaultHost.remoteHost, equals('localhost'));
          expect(profileWithDefaultHost.displayName, equals(testDisplayName));
        },
      );
    });

    group('Profile Equality and String Representation', () {
      test('should implement equality correctly', () {
        const profile1 = Profile(
          testUuid,
          displayName: testDisplayName,
          sshnpdAtsign: testSshnpdAtsign,
          deviceName: testDeviceName,
          remotePort: testRemotePort,
          localPort: testLocalPort,
        );

        const profile2 = Profile(
          testUuid,
          displayName: testDisplayName,
          sshnpdAtsign: testSshnpdAtsign,
          deviceName: testDeviceName,
          remotePort: testRemotePort,
          localPort: testLocalPort,
        );

        final profile3 = testProfile.copyWith(uuid: 'different-uuid');
        final profile4 = testProfile.copyWith(displayName: 'Different Name');

        // Test equality when all properties match
        expect(profile1, equals(profile2));
        expect(profile1.hashCode, equals(profile2.hashCode));

        // Test inequality when properties differ
        expect(testProfile, isNot(equals(profile3)));
        expect(testProfile, isNot(equals(profile4)));
      });

      test('should provide readable string representation', () {
        final stringRepresentation = testProfile.toString();

        expect(
          stringRepresentation,
          allOf(
            contains(testDisplayName),
            contains(testSshnpdAtsign),
            contains(testDeviceName),
            contains(testUuid),
          ),
        );
      });
    });

    group('Profile Favoritable Mixin', () {
      test('should implement Favoritable mixin', () {
        expect(testProfile, isA<Favoritable>());
      });

      // Note: isInFavorites test would require Favorite objects which depend on this Profile
      // This will be tested in the integration tests
    });

    group('Profile toNptParams', () {
      test('should convert to NptParams with all parameters', () {
        const clientAtsign = '@client';
        const rootDomain = 'test.domain.com';
        const fallbackRelayAtsign = '@fallback_relay';

        final nptParams = testProfile.toNptParams(
          clientAtsign: clientAtsign,
          rootDomain: rootDomain,
          fallbackRelayAtsign: fallbackRelayAtsign,
        );

        expect(nptParams.clientAtSign, equals(clientAtsign));
        expect(nptParams.sshnpdAtSign, equals(testSshnpdAtsign));
        expect(
          nptParams.srvdAtSign,
          equals(testRelayAtsign),
        ); // Should use profile's relay
        expect(nptParams.remoteHost, equals(testRemoteHost));
        expect(nptParams.remotePort, equals(testRemotePort));
        expect(nptParams.device, equals(testDeviceName));
        expect(nptParams.localPort, equals(testLocalPort));
        expect(nptParams.rootDomain, equals(rootDomain));
      });

      test(
        'should use fallback relay when overrideRelayWithFallback is true',
        () {
          const clientAtsign = '@client';
          const rootDomain = 'test.domain.com';
          const fallbackRelayAtsign = '@fallback_relay';

          final nptParams = testProfile.toNptParams(
            clientAtsign: clientAtsign,
            rootDomain: rootDomain,
            fallbackRelayAtsign: fallbackRelayAtsign,
            overrideRelayWithFallback: true,
          );

          expect(
            nptParams.srvdAtSign,
            equals(fallbackRelayAtsign),
          ); // Should use fallback
        },
      );

      test('should use fallback relay when profile relay is null', () {
        const profileWithoutRelay = Profile(
          testUuid,
          displayName: testDisplayName,
          sshnpdAtsign: testSshnpdAtsign,
          deviceName: testDeviceName,
          remotePort: testRemotePort,
          localPort: testLocalPort,
        );

        const clientAtsign = '@client';
        const rootDomain = 'test.domain.com';
        const fallbackRelayAtsign = '@fallback_relay';

        final nptParams = profileWithoutRelay.toNptParams(
          clientAtsign: clientAtsign,
          rootDomain: rootDomain,
          fallbackRelayAtsign: fallbackRelayAtsign,
        );

        expect(nptParams.srvdAtSign, equals(fallbackRelayAtsign));
      });

      test('should use fallback relay when profile relay is empty', () {
        final profileWithEmptyRelay = testProfile.copyWith(relayAtsign: '');

        const clientAtsign = '@client';
        const rootDomain = 'test.domain.com';
        const fallbackRelayAtsign = '@fallback_relay';

        final nptParams = profileWithEmptyRelay.toNptParams(
          clientAtsign: clientAtsign,
          rootDomain: rootDomain,
          fallbackRelayAtsign: fallbackRelayAtsign,
        );

        expect(nptParams.srvdAtSign, equals(fallbackRelayAtsign));
      });
    });

    group('Profile fromJson with uuid parameter', () {
      test('should use provided uuid parameter when profile uuid is empty', () {
        final json = {
          'displayName': testDisplayName,
          'sshnpdAtsign': testSshnpdAtsign,
          'deviceName': testDeviceName,
          'remotePort': testRemotePort,
          'localPort': testLocalPort,
        };

        const providedUuid = 'provided-uuid-123';
        final profile = Profile.fromJson(json, uuid: providedUuid);

        expect(profile.uuid, equals(providedUuid));
      });

      test(
        'should generate uuid when profile uuid is empty and no uuid provided',
        () {
          final json = {
            'displayName': testDisplayName,
            'sshnpdAtsign': testSshnpdAtsign,
            'deviceName': testDeviceName,
            'remotePort': testRemotePort,
            'localPort': testLocalPort,
          };

          final profile = Profile.fromJson(json);

          expect(profile.uuid, isNotEmpty);
          expect(profile.uuid, isNot(equals('')));
        },
      );

      test(
        'should keep existing uuid when profile already has one and no new uuid is passed in',
        () {
          final json = {
            'uuid': testUuid,
            'displayName': testDisplayName,
            'sshnpdAtsign': testSshnpdAtsign,
            'deviceName': testDeviceName,
            'remotePort': testRemotePort,
            'localPort': testLocalPort,
          };

          const providedUuid = 'provided-uuid-123';
          var profile = Profile.fromJson(json, uuid: null);

          expect(profile.uuid, equals(testUuid)); // Should keep original uuid
          profile = Profile.fromJson(json, uuid: providedUuid);
          expect(
            profile.uuid,
            equals(providedUuid),
          ); // Should use provided uuid
        },
      );
    });
  });
}
