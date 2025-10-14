import 'package:test/test.dart';
import 'package:noports_core/src/common/host_validator.dart';
import 'dart:io';

void main() {
  group('HostValidator Tests', () {
    group('isValidHost() tests', () {
      test('should accept valid IPv4 addresses', () async {
        expect(await HostValidator.isValidHost('127.0.0.1'), isTrue);
        expect(await HostValidator.isValidHost('192.168.1.100'), isTrue);
        expect(await HostValidator.isValidHost('10.0.0.1'), isTrue);
        expect(await HostValidator.isValidHost('0.0.0.0'), isTrue);
        expect(await HostValidator.isValidHost('255.255.255.255'), isTrue);
      });

      test('should accept valid IPv6 addresses', () async {
        expect(await HostValidator.isValidHost('::1'), isTrue);
        expect(await HostValidator.isValidHost('2001:db8::1'), isTrue);
        expect(await HostValidator.isValidHost('fe80::1'), isTrue);
        expect(await HostValidator.isValidHost('::ffff:192.168.1.1'), isTrue);
      });

      test('should accept valid hostnames', () async {
        expect(await HostValidator.isValidHost('localhost'), isTrue);
      });

      test('should reject invalid IP addresses', () async {
        expect(await HostValidator.isValidHost('999.999.999.999'), isFalse);
        expect(await HostValidator.isValidHost('256.1.1.1'), isFalse);
        expect(await HostValidator.isValidHost('192.168.1.1.1'), isFalse);
        expect(await HostValidator.isValidHost('300.400.500.600'), isFalse);
      });

      test('should reject invalid hostnames', () async {
        expect(
          await HostValidator.isValidHost(
            'definitely-not-a-valid-hostname-that-should-never-resolve-12345678',
          ),
          isFalse,
        );
        expect(
          await HostValidator.isValidHost('invalid..hostname..with..dots'),
          isFalse,
        );
      });

      test('should reject empty or whitespace-only input', () async {
        expect(await HostValidator.isValidHost(''), isFalse);
        expect(await HostValidator.isValidHost('   '), isFalse);
        expect(await HostValidator.isValidHost('\t'), isFalse);
      });

      test('should trim whitespace from input', () async {
        expect(await HostValidator.isValidHost('  127.0.0.1  '), isTrue);
        expect(await HostValidator.isValidHost('\tlocalhost\n'), isTrue);
      });
    });

    group('findFirstValidHost() tests', () {
      test('should return first valid IP from comma-separated list', () async {
        String? result = await HostValidator.findFirstValidHost(
          '999.999.999.999,127.0.0.1,192.168.1.100',
        );
        expect(result, equals('127.0.0.1'));
      });

      test('should skip invalid IPs and find valid one', () async {
        String? result = await HostValidator.findFirstValidHost(
          '256.1.1.1,999.999.999.999,127.0.0.1',
        );
        expect(result, equals('127.0.0.1'));
      });

      test('should handle hostnames', () async {
        String? result = await HostValidator.findFirstValidHost(
          'invalid-hostname-12345,localhost',
        );
        expect(result, equals('localhost'));
      });

      test('should return null for all invalid inputs', () async {
        String? result = await HostValidator.findFirstValidHost(
          '999.999.999.999,256.1.1.1,invalid-hostname-12345',
        );
        expect(result, isNull);
      });

      test('should handle whitespace correctly', () async {
        String? result = await HostValidator.findFirstValidHost(
          ' 999.999.999.999 , 127.0.0.1 , 192.168.1.100 ',
        );
        expect(result, equals('127.0.0.1'));
      });

      test('should handle empty input', () async {
        String? result = await HostValidator.findFirstValidHost('');
        expect(result, isNull);
      });

      test('should handle single valid host', () async {
        String? result = await HostValidator.findFirstValidHost('127.0.0.1');
        expect(result, equals('127.0.0.1'));
      });

      test('should handle single invalid host', () async {
        String? result = await HostValidator.findFirstValidHost(
          '999.999.999.999',
        );
        expect(result, isNull);
      });
    });

    group('findValidHosts() tests', () {
      test('should return all valid hosts from mixed list', () async {
        List<String> result = await HostValidator.findValidHosts(
          '999.999.999.999,127.0.0.1,256.1.1.1,localhost,192.168.1.100',
        );
        expect(
          result,
          containsAll(['127.0.0.1', 'localhost', '192.168.1.100']),
        );
        expect(result.length, equals(3));
      });

      test('should return empty list for all invalid hosts', () async {
        List<String> result = await HostValidator.findValidHosts(
          '999.999.999.999,256.1.1.1,invalid-hostname-12345',
        );
        expect(result, isEmpty);
      });

      test('should return all hosts when all are valid', () async {
        List<String> result = await HostValidator.findValidHosts(
          '127.0.0.1,localhost,::1',
        );
        expect(result.length, equals(3));
        expect(result, containsAll(['127.0.0.1', 'localhost', '::1']));
      });

      test('should handle empty input', () async {
        List<String> result = await HostValidator.findValidHosts('');
        expect(result, isEmpty);
      });
    });

    group('parseHostsList() tests', () {
      test('should split comma-separated hosts', () {
        List<String> result = HostValidator.parseHostsList(
          '127.0.0.1,192.168.1.100,localhost',
        );
        expect(result, equals(['127.0.0.1', '192.168.1.100', 'localhost']));
      });

      test('should trim whitespace from hosts', () {
        List<String> result = HostValidator.parseHostsList(
          ' 127.0.0.1 , 192.168.1.100 , localhost ',
        );
        expect(result, equals(['127.0.0.1', '192.168.1.100', 'localhost']));
      });

      test('should filter out empty entries', () {
        List<String> result = HostValidator.parseHostsList(
          '127.0.0.1,,192.168.1.100, ,localhost',
        );
        expect(result, equals(['127.0.0.1', '192.168.1.100', 'localhost']));
      });

      test('should handle single host', () {
        List<String> result = HostValidator.parseHostsList('127.0.0.1');
        expect(result, equals(['127.0.0.1']));
      });

      test('should handle empty string', () {
        List<String> result = HostValidator.parseHostsList('');
        expect(result, isEmpty);
      });

      test('should handle only commas and whitespace', () {
        List<String> result = HostValidator.parseHostsList(',, , ,');
        expect(result, isEmpty);
      });
    });

    group('Integration tests', () {
      test('should work with complex real-world scenarios', () async {
        // Test with mix of invalid IPs, invalid hostnames, and valid addresses
        String? result = await HostValidator.findFirstValidHost(
          '999.999.999.999, invalid-hostname-12345, 256.1.1.1, localhost, 192.168.1.100',
        );
        expect(result, equals('localhost'));
      });

      test('should handle IPv6 addresses in comma-separated list', () async {
        String? result = await HostValidator.findFirstValidHost(
          'invalid-ipv6::, ::1, 2001:db8::1',
        );
        expect(result, equals('::1'));
      });

      test('should work with edge case whitespace', () async {
        String? result = await HostValidator.findFirstValidHost(
          '  ,  , 127.0.0.1  ,  ',
        );
        expect(result, equals('127.0.0.1'));
      });
    });

    group('IPv4/IPv6 Integration Tests', () {
      test('canBind should work with IPv4 flag', () async {
        final canBindIPv4 = await HostValidator.canBind(
          'localhost',
          0, // Use OS-assigned port
          addressType: InternetAddressType.IPv4,
        );
        expect(
          canBindIPv4,
          isTrue,
          reason: 'Should be able to bind to IPv4 localhost',
        );
      });

      test('canBind should work with IPv6 flag if available', () async {
        final canBindIPv6 = await HostValidator.canBind(
          'localhost',
          0, // Use OS-assigned port
          addressType: InternetAddressType.IPv6,
        );
        // IPv6 might not be available on all systems, so we just test it doesn't crash
        expect(canBindIPv6, isA<bool>());
      });

      test('resolveHost should respect address type filtering', () async {
        final ipv4Address = await HostValidator.resolveHost(
          'localhost',
          addressType: InternetAddressType.IPv4,
        );

        if (ipv4Address != null) {
          expect(ipv4Address.type, equals(InternetAddressType.IPv4));
          expect(ipv4Address.address, equals('127.0.0.1'));
        }
      });

      test(
        'findBindableHost should find available host with address type',
        () async {
          final bindableHost = await HostValidator.findBindableHost(
            'localhost,127.0.0.1',
            0, // Use OS-assigned port
            addressType: InternetAddressType.IPv4,
          );

          expect(bindableHost, isNotNull);
          expect(['localhost', '127.0.0.1'].contains(bindableHost), isTrue);
        },
      );

      test('findBindableHost should handle fallback list correctly', () async {
        // Test with a mix of valid and invalid hosts
        final bindableHost = await HostValidator.findBindableHost(
          'invalid-host-999999,localhost,127.0.0.1',
          0, // Use OS-assigned port
          addressType: InternetAddressType.IPv4,
        );

        expect(bindableHost, isNotNull);
        expect(['localhost', '127.0.0.1'].contains(bindableHost), isTrue);
      });
    });
  });
}
