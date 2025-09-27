import 'dart:io';
import 'package:test/test.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:noports_core/utils.dart';

void main() {
  group('Local Host Integration Tests', () {
    test('end-to-end: CLI argument to NptParams to socket binding simulation', () async {
      // Simulate CLI argument parsing
      String cliArg = '192.168.1.100,127.0.0.1';
      
      // Parse like the main application does
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, equals('192.168.1.100'));
      
      // Create NptParams with the selected host
      final params = NptParams(
        clientAtSign: '@client',
        sshnpdAtSign: '@daemon',
        srvdAtSign: '@relay',
        device: 'test_device',
        inline: false,
        remoteHost: 'localhost',
        remotePort: 22,
        timeout: DefaultArgs.srvTimeout,
        localHost: selectedHost,
      );
      
      expect(params.localHost, equals('192.168.1.100'));
      
      // Simulate what srv_impl.dart does - resolve the address
      InternetAddress? resolvedAddress = await resolveLocalHost(params.localHost);
      expect(resolvedAddress, isNotNull);
      expect(resolvedAddress!.address, equals('192.168.1.100'));
    });

    test('integration: localhost fallback when first IP is invalid', () async {
      String cliArg = '999.999.999.999,127.0.0.1';
      
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, equals('127.0.0.1'));
      
      final params = NptParams(
        clientAtSign: '@client',
        sshnpdAtSign: '@daemon',
        srvdAtSign: '@relay',
        device: 'test_device',
        inline: false,
        remoteHost: 'localhost',
        remotePort: 22,
        timeout: DefaultArgs.srvTimeout,
        localHost: selectedHost,
      );
      
      expect(params.localHost, equals('127.0.0.1'));
      
      InternetAddress? resolvedAddress = await resolveLocalHost(params.localHost);
      expect(resolvedAddress, isNotNull);
      expect(resolvedAddress!.isLoopback, isTrue);
    });

    test('integration: hostname resolution works', () async {
      String cliArg = 'localhost,192.168.1.100';
      
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, equals('localhost'));
      
      final params = NptParams(
        clientAtSign: '@client',
        sshnpdAtSign: '@daemon',
        srvdAtSign: '@relay',
        device: 'test_device',
        inline: false,
        remoteHost: 'localhost',
        remotePort: 22,
        timeout: DefaultArgs.srvTimeout,
        localHost: selectedHost,
      );
      
      expect(params.localHost, equals('localhost'));
      
      InternetAddress? resolvedAddress = await resolveLocalHost(params.localHost);
      expect(resolvedAddress, isNotNull);
      // localhost should resolve to loopback
      expect(resolvedAddress!.isLoopback, isTrue);
    });

    test('integration: IPv6 address handling', () async {
      String cliArg = '::1,127.0.0.1';
      
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, equals('::1'));
      
      final params = NptParams(
        clientAtSign: '@client',
        sshnpdAtSign: '@daemon',
        srvdAtSign: '@relay',
        device: 'test_device',
        inline: false,
        remoteHost: 'localhost',
        remotePort: 22,
        timeout: DefaultArgs.srvTimeout,
        localHost: selectedHost,
      );
      
      expect(params.localHost, equals('::1'));
      
      InternetAddress? resolvedAddress = await resolveLocalHost(params.localHost);
      expect(resolvedAddress, isNotNull);
      expect(resolvedAddress!.type, equals(InternetAddressType.IPv6));
    });

    test('integration: port binding simulation', () async {
      // Test that we can actually attempt to bind to resolved addresses
      final testAddresses = ['127.0.0.1', '::1'];
      
      for (String address in testAddresses) {
        final params = NptParams(
          clientAtSign: '@client',
          sshnpdAtSign: '@daemon',
          srvdAtSign: '@relay',
          device: 'test_device',
          inline: false,
          remoteHost: 'localhost',
          remotePort: 22,
          timeout: DefaultArgs.srvTimeout,
          localHost: address,
        );
        
        InternetAddress? resolvedAddress = await resolveLocalHost(params.localHost);
        expect(resolvedAddress, isNotNull);
        
        // Test that we can actually bind to this address (using port 0 for any available port)
        ServerSocket? server;
        try {
          server = await ServerSocket.bind(resolvedAddress!, 0);
          expect(server.port, greaterThan(0));
          await server.close();
        } catch (e) {
          // Some systems might not support IPv6, so we'll allow this to fail gracefully
          if (resolvedAddress!.type == InternetAddressType.IPv6) {
            // IPv6 binding might fail on some systems
          } else {
            rethrow;
          }
        }
      }
    });
  });

  group('Error Handling Integration Tests', () {
    test('integration: all invalid IPs should throw error', () async {
      String cliArg = '999.999.999.999,300.300.300.300';
      
      expect(
        () => parseFirstValidHost(cliArg),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('integration: empty string handling', () async {
      String cliArg = '';
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, isNull);
      
      // When localHost is null, the system should default to localhost behavior
      final params = NptParams(
        clientAtSign: '@client',
        sshnpdAtSign: '@daemon',
        srvdAtSign: '@relay',
        device: 'test_device',
        inline: false,
        remoteHost: 'localhost',
        remotePort: 22,
        timeout: DefaultArgs.srvTimeout,
        localHost: selectedHost,
      );
      
      expect(params.localHost, isNull);
    });

    test('integration: whitespace only string handling', () async {
      String cliArg = '   ';
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, isNull);
    });

    test('integration: mixed valid/invalid with whitespace', () async {
      String cliArg = ' 999.999.999.999 , 192.168.1.100 , 300.300.300.300 ';
      
      String? selectedHost = await parseFirstValidHost(cliArg);
      expect(selectedHost, equals('192.168.1.100'));
    });
  });
}

/// Helper function that mimics the parsing logic from npt.dart
Future<String?> parseFirstValidHost(String input) async {
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

/// Helper function that mimics the resolution logic from srv_impl.dart
Future<InternetAddress?> resolveLocalHost(String? hostToLookup) async {
  if (hostToLookup == null) {
    return InternetAddress.loopbackIPv4;
  }
  
  List<InternetAddress> candidates = [];
  
  try {
    candidates = await InternetAddress.lookup(
      hostToLookup,
      type: InternetAddressType.IPv4,
    );
  } catch (e) {
    // Try IPv6 if IPv4 fails
    try {
      candidates = await InternetAddress.lookup(
        hostToLookup,
        type: InternetAddressType.IPv6,
      );
    } catch (e2) {
      throw Exception("Cannot resolve address for $hostToLookup");
    }
  }
  
  if (candidates.isEmpty) {
    throw Exception("Cannot resolve address for $hostToLookup");
  }
  
  return candidates.first;
}