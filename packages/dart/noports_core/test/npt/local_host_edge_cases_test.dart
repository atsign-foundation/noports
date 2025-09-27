import 'dart:io';
import 'package:test/test.dart';

void main() {
  group('Local Host Edge Cases', () {
    group('IP Address Validation Edge Cases', () {
      test('boundary IPv4 addresses', () {
        // Test edge cases for IPv4
        expect(() => InternetAddress('0.0.0.0'), returnsNormally);
        expect(() => InternetAddress('255.255.255.255'), returnsNormally);
        expect(() => InternetAddress('127.0.0.1'), returnsNormally);
        expect(() => InternetAddress('192.168.255.255'), returnsNormally);
        expect(() => InternetAddress('10.255.255.255'), returnsNormally);
        expect(() => InternetAddress('172.31.255.255'), returnsNormally);
      });

      test('invalid IPv4 boundary cases', () {
        expect(() => InternetAddress('256.0.0.0'), throwsArgumentError);
        expect(() => InternetAddress('0.256.0.0'), throwsArgumentError);
        expect(() => InternetAddress('0.0.256.0'), throwsArgumentError);
        expect(() => InternetAddress('0.0.0.256'), throwsArgumentError);
        expect(() => InternetAddress('-1.0.0.0'), throwsArgumentError);
        expect(() => InternetAddress('0.-1.0.0'), throwsArgumentError);
      });

      test('malformed IPv4 addresses', () {
        expect(() => InternetAddress('192.168.1'), throwsArgumentError);
        expect(() => InternetAddress('192.168'), throwsArgumentError);
        expect(() => InternetAddress('192'), throwsArgumentError);
        expect(() => InternetAddress('192.168.1.1.1'), throwsArgumentError);
        expect(() => InternetAddress('192.168.1.'), throwsArgumentError);
        expect(() => InternetAddress('.192.168.1.1'), throwsArgumentError);
        expect(() => InternetAddress('192..168.1.1'), throwsArgumentError);
      });

      test('IPv6 edge cases', () {
        expect(() => InternetAddress('::'), returnsNormally);
        expect(() => InternetAddress('::1'), returnsNormally);
        expect(() => InternetAddress('::ffff:192.168.1.1'), returnsNormally);
        expect(() => InternetAddress('2001:db8::1'), returnsNormally);
        expect(() => InternetAddress('fe80::1'), returnsNormally);
        expect(() => InternetAddress('::ffff:0:0'), returnsNormally);
      });

      test('invalid IPv6 addresses', () {
        expect(() => InternetAddress(':::'), throwsArgumentError);
        expect(() => InternetAddress('2001:db8::1::1'), throwsArgumentError);
        expect(() => InternetAddress('2001:db8:g::1'), throwsArgumentError);
        expect(() => InternetAddress('2001:db8::12345'), throwsArgumentError);
      });

      test('non-IP strings', () {
        expect(() => InternetAddress('not-an-ip'), throwsArgumentError);
        expect(() => InternetAddress('192.168.1.abc'), throwsArgumentError);
        expect(() => InternetAddress('hello.world'), throwsArgumentError);
        expect(() => InternetAddress(''), throwsArgumentError);
        expect(() => InternetAddress(' '), throwsArgumentError);
      });
    });

    group('Hostname Resolution Edge Cases', () {
      test('localhost variations', () async {
        // These should all resolve successfully
        final hostnames = ['localhost', 'LOCALHOST', 'LocalHost'];
        
        for (String hostname in hostnames) {
          try {
            final addresses = await InternetAddress.lookup(hostname);
            expect(addresses, isNotEmpty);
            expect(addresses.first.isLoopback, isTrue);
          } catch (e) {
            // Some systems might be case-sensitive, so we allow failures for non-lowercase
            if (hostname != 'localhost') {
              continue;
            }
            rethrow;
          }
        }
      });

      test('invalid hostnames', () async {
        final invalidHostnames = [
          'definitely-not-a-valid-hostname-12345',
          'invalid..hostname',
          'hostname-with-very-long-name-that-exceeds-typical-limits-and-should-fail',
          '192.168.1.999', // Invalid IP that might be treated as hostname
        ];
        
        for (String hostname in invalidHostnames) {
          expect(
            () => InternetAddress.lookup(hostname),
            throwsA(isA<SocketException>()),
          );
        }
      });

      test('special hostname cases', () async {
        // Test some special cases that might behave differently on different systems
        final specialCases = [
          '0.0.0.0', // Should be valid IP
          '127.0.0.1', // Should be valid IP
          'broadcasthost', // macOS specific hostname
        ];
        
        for (String hostname in specialCases) {
          try {
            final addresses = await InternetAddress.lookup(hostname);
            expect(addresses, isNotEmpty);
          } catch (e) {
            // These might fail on some systems, which is OK for edge case testing
            expect(e, isA<SocketException>());
          }
        }
      });
    });

    group('Input Parsing Edge Cases', () {
      test('extreme whitespace cases', () async {
        final testCases = {
          '   127.0.0.1   ': '127.0.0.1',
          '\t192.168.1.1\t': '192.168.1.1',
          '\n127.0.0.1\n': '127.0.0.1',
          '  127.0.0.1  ,  192.168.1.1  ': '127.0.0.1',
          ' , , 127.0.0.1 , , ': '127.0.0.1',
        };
        
        for (MapEntry<String, String> testCase in testCases.entries) {
          final result = await parseAndValidateLocalHosts(testCase.key);
          expect(result, equals(testCase.value));
        }
      });

      test('comma variations', () async {
        final testCases = {
          '127.0.0.1,192.168.1.1': '127.0.0.1',
          '127.0.0.1, 192.168.1.1': '127.0.0.1',
          '127.0.0.1 ,192.168.1.1': '127.0.0.1',
          '127.0.0.1 , 192.168.1.1': '127.0.0.1',
          '127.0.0.1,,192.168.1.1': '127.0.0.1', // Double comma
          '127.0.0.1,  ,192.168.1.1': '127.0.0.1', // Empty element
        };
        
        for (MapEntry<String, String> testCase in testCases.entries) {
          final result = await parseAndValidateLocalHosts(testCase.key);
          expect(result, equals(testCase.value));
        }
      });

      test('mixed IPv4 and IPv6', () async {
        final testCases = {
          '::1,127.0.0.1': '::1',
          '127.0.0.1,::1': '127.0.0.1',
          '192.168.1.1,2001:db8::1,10.0.0.1': '192.168.1.1',
          '999.999.999.999,::1,invalid,127.0.0.1': '::1', // First valid is IPv6
        };
        
        for (MapEntry<String, String> testCase in testCases.entries) {
          final result = await parseAndValidateLocalHosts(testCase.key);
          expect(result, equals(testCase.value));
        }
      });

      test('extreme lengths', () async {
        // Test very long input strings
        final manyInvalidIPs = List.generate(100, (i) => '999.999.999.$i').join(',');
        final longInputWithValidAtEnd = '$manyInvalidIPs,127.0.0.1';
        
        final result = await parseAndValidateLocalHosts(longInputWithValidAtEnd);
        expect(result, equals('127.0.0.1'));
      });

      test('single character inputs', () async {
        // Test whitespace characters that should return null
        final whitespaceChars = [' ', '\t', '\n'];
        for (String input in whitespaceChars) {
          final result = await parseAndValidateLocalHosts(input);
          expect(result, isNull);
        }
        
        // Test obviously invalid single characters that should throw
        final invalidSingleChars = ['.', ','];
        for (String input in invalidSingleChars) {
          expect(
            () => parseAndValidateLocalHosts(input),
            throwsA(isA<ArgumentError>()),
          );
        }
        
        // Note: Single letters like 'a' or '1' might actually resolve as hostnames 
        // on some systems, so we test them separately and allow either outcome
        final ambiguousChars = ['a', '1'];
        for (String input in ambiguousChars) {
          try {
            final result = await parseAndValidateLocalHosts(input);
            // If it resolves, that's fine
            expect(result, equals(input));
          } catch (e) {
            // If it doesn't resolve, that's also fine
            expect(e, isA<ArgumentError>());
          }
        }
      });
    });

    group('Real-world Network Scenarios', () {
      test('private network ranges', () async {
        final privateRanges = [
          '10.0.0.1',      // Class A private
          '172.16.0.1',    // Class B private
          '192.168.0.1',   // Class C private
          '192.168.1.1',   // Common router IP
          '192.168.0.254', // Common router IP
          '10.0.0.254',    // Common router IP
        ];
        
        for (String ip in privateRanges) {
          // These should all parse as valid IPs (even if not reachable)
          expect(() => InternetAddress(ip), returnsNormally);
          
          final result = await parseAndValidateLocalHosts(ip);
          expect(result, equals(ip));
        }
      });

      test('public IP addresses', () async {
        final publicIPs = [
          '8.8.8.8',       // Google DNS
          '1.1.1.1',       // Cloudflare DNS
          '208.67.222.222', // OpenDNS
        ];
        
        for (String ip in publicIPs) {
          expect(() => InternetAddress(ip), returnsNormally);
          
          final result = await parseAndValidateLocalHosts(ip);
          expect(result, equals(ip));
        }
      });

      test('loopback variations', () async {
        final loopbackIPs = [
          '127.0.0.1',
          '127.0.0.2',     // Also loopback
          '127.1.1.1',     // Also loopback
          '127.255.255.254', // Also loopback
        ];
        
        for (String ip in loopbackIPs) {
          expect(() => InternetAddress(ip), returnsNormally);
          
          final result = await parseAndValidateLocalHosts(ip);
          expect(result, equals(ip));
          
          final addr = InternetAddress(ip);
          expect(addr.isLoopback, isTrue);
        }
      });
    });
  });
}

/// Test helper function that mimics the logic from npt.dart
Future<String?> parseAndValidateLocalHosts(String input) async {
  if (input.trim().isEmpty) {
    return null;
  }

  final parsedHosts = input
      .split(',')
      .map<String>((ip) => ip.trim())
      .where((String ip) => ip.isNotEmpty)
      .toList();

  // Find the first valid IP address from the list
  for (String ip in parsedHosts) {
    bool isValid = false;
    try {
      // Try to parse as IP address - this will throw if invalid
      InternetAddress(ip);
      isValid = true;
    } catch (e) {
      // If not a valid IP, try to resolve as hostname
      try {
        await InternetAddress.lookup(ip);
        isValid = true;
      } catch (e2) {
        // Continue to next IP
      }
    }
    
    if (isValid) {
      return ip;
    }
  }
  
  throw ArgumentError('No valid IP addresses found in: ${parsedHosts.join(', ')}');
}