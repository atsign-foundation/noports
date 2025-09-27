import 'dart:io';
import 'package:test/test.dart';
import 'package:args/args.dart';

void main() {
  group('Local Host CLI Argument Tests', () {
    late ArgParser parser;

    setUp(() {
      // Create a basic parser similar to what npt uses
      parser = ArgParser();
      parser.addOption(
        'local-host',
        aliases: ['lh'],
        help: 'Local IP address to bind to, or comma-separated list with fallbacks.'
            ' When specified, npt will act as a gateway by binding to the'
            ' first available IP instead of the default localhost (127.0.0.1).'
            ' If multiple IPs are provided, only the first valid one is used.'
            ' Example: --local-host 192.168.1.100,10.0.0.50'
            ' Alias: --lh',
      );
    });

    test('single valid IP address', () {
      final args = parser.parse(['--local-host', '192.168.1.100']);
      expect(args['local-host'], equals('192.168.1.100'));
    });

    test('multiple IP addresses comma-separated', () {
      final args = parser.parse(['--local-host', '192.168.1.100,10.0.0.50']);
      expect(args['local-host'], equals('192.168.1.100,10.0.0.50'));
    });

    test('alias --lh works', () {
      final args = parser.parse(['--lh', '127.0.0.1']);
      expect(args['local-host'], equals('127.0.0.1'));
    });

    test('localhost address', () {
      final args = parser.parse(['--local-host', '127.0.0.1']);
      expect(args['local-host'], equals('127.0.0.1'));
    });

    test('IPv6 localhost', () {
      final args = parser.parse(['--local-host', '::1']);
      expect(args['local-host'], equals('::1'));
    });

    test('hostname instead of IP', () {
      final args = parser.parse(['--local-host', 'localhost']);
      expect(args['local-host'], equals('localhost'));
    });
  });

  group('IP Address Parsing Logic Tests', () {
    test('parseLocalHosts - single valid IP', () async {
      final result = await parseAndValidateLocalHosts('192.168.1.100');
      expect(result, equals('192.168.1.100'));
    });

    test('parseLocalHosts - first of multiple valid IPs', () async {
      final result = await parseAndValidateLocalHosts('192.168.1.100,10.0.0.50');
      expect(result, equals('192.168.1.100'));
    });

    test('parseLocalHosts - localhost hostname', () async {
      final result = await parseAndValidateLocalHosts('localhost');
      expect(result, equals('localhost'));
    });

    test('parseLocalHosts - mixed valid and invalid', () async {
      final result = await parseAndValidateLocalHosts('999.999.999.999,192.168.1.100');
      expect(result, equals('192.168.1.100'));
    });

    test('parseLocalHosts - all invalid IPs throws error', () async {
      expect(
        () => parseAndValidateLocalHosts('999.999.999.999,300.300.300.300'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parseLocalHosts - empty string returns null', () async {
      final result = await parseAndValidateLocalHosts('');
      expect(result, isNull);
    });

    test('parseLocalHosts - whitespace handling', () async {
      final result = await parseAndValidateLocalHosts(' 192.168.1.100 , 10.0.0.50 ');
      expect(result, equals('192.168.1.100'));
    });

    test('parseLocalHosts - single invalid IP throws error', () async {
      expect(
        () => parseAndValidateLocalHosts('999.999.999.999'),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('parseLocalHosts - IPv6 addresses', () async {
      final result = await parseAndValidateLocalHosts('::1,127.0.0.1');
      expect(result, equals('::1'));
    });
  });

  group('IP Address Validation Tests', () {
    test('valid IPv4 addresses', () {
      expect(() => InternetAddress('192.168.1.100'), returnsNormally);
      expect(() => InternetAddress('127.0.0.1'), returnsNormally);
      expect(() => InternetAddress('10.0.0.1'), returnsNormally);
      expect(() => InternetAddress('172.16.0.1'), returnsNormally);
    });

    test('valid IPv6 addresses', () {
      expect(() => InternetAddress('::1'), returnsNormally);
      expect(() => InternetAddress('2001:db8::1'), returnsNormally);
    });

    test('invalid IP addresses throw exceptions', () {
      expect(() => InternetAddress('999.999.999.999'), throwsArgumentError);
      expect(() => InternetAddress('256.1.1.1'), throwsArgumentError);
      expect(() => InternetAddress('1.1.1'), throwsArgumentError);
      expect(() => InternetAddress('not-an-ip'), throwsArgumentError);
    });

    test('edge case IP addresses', () {
      expect(() => InternetAddress('0.0.0.0'), returnsNormally);
      expect(() => InternetAddress('255.255.255.255'), returnsNormally);
    });
  });
}

/// Test helper function that mimics the logic from npt.dart
/// This simulates the parsing and validation logic from the main application
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