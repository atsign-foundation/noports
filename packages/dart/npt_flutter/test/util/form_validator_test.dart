import 'package:test/test.dart';
import 'package:npt_flutter/util/form_validator.dart';

void main() {
  group('validateHostPortField', () {
    test('should accept valid localhost with port', () {
      final result = FormValidator.validateHostPortField('localhost:8080');
      expect(result, isNull);
    });

    test('should accept valid IPv4 address with port', () {
      final result = FormValidator.validateHostPortField('127.0.0.1:443');
      expect(result, isNull);
    });

    test('should accept valid IPv6 loopback with port (::1:443)', () {
      final result = FormValidator.validateHostPortField('::1:443');
      expect(result, isNull);
    });

    test('should accept valid IPv6 address with port (fe80::1:8080)', () {
      final result = FormValidator.validateHostPortField('fe80::1:8080');
      expect(result, isNull);
    });

    test('should accept valid full IPv6 address with port', () {
      final result = FormValidator.validateHostPortField(
          '2001:0db8:85a3::8a2e:0370:7334:22');
      expect(result, isNull);
    });

    test('should accept wildcard host with wildcard port (*:*)', () {
      final result = FormValidator.validateHostPortField('*:*');
      expect(result, isNull);
    });

    test('should accept localhost with wildcard port (localhost:*)', () {
      final result = FormValidator.validateHostPortField('localhost:*');
      expect(result, isNull);
    });

    test('should accept IPv6 with wildcard port (::1:*)', () {
      final result = FormValidator.validateHostPortField('::1:*');
      expect(result, isNull);
    });

    test('should accept minimum port number (1)', () {
      final result = FormValidator.validateHostPortField('localhost:1');
      expect(result, isNull);
    });

    test('should accept maximum port number (65535)', () {
      final result = FormValidator.validateHostPortField('localhost:65535');
      expect(result, isNull);
    });

    test('should reject empty value', () {
      final result = FormValidator.validateHostPortField('');
      expect(result, isNotNull);
      expect(result, contains('field'));
    });

    test('should reject null value', () {
      final result = FormValidator.validateHostPortField(null);
      expect(result, isNotNull);
      expect(result, contains('field'));
    });

    test('should reject value without colon', () {
      final result = FormValidator.validateHostPortField('localhost8080');
      expect(result, isNotNull);
      expect(result, contains('colon'));
    });

    test('should reject empty host with port (:8080)', () {
      final result = FormValidator.validateHostPortField(':8080');
      expect(result, isNotNull);
      expect(result, contains('Host part cannot be empty'));
    });

    test('should reject host without port (localhost:)', () {
      final result = FormValidator.validateHostPortField('localhost:');
      expect(result, isNotNull);
      expect(result, contains('Port part cannot be empty'));
    });

    test('should reject invalid port (non-numeric)', () {
      final result = FormValidator.validateHostPortField('localhost:abc');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    test('should reject port 0', () {
      final result = FormValidator.validateHostPortField('localhost:0');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    test('should reject port above 65535', () {
      final result = FormValidator.validateHostPortField('localhost:65536');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    test('should reject negative port', () {
      final result = FormValidator.validateHostPortField('localhost:-1');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    test('should accept hostname with hyphens', () {
      final result = FormValidator.validateHostPortField('my-host-name:8080');
      expect(result, isNull);
    });

    test('should accept FQDN with port', () {
      final result = FormValidator.validateHostPortField('example.com:443');
      expect(result, isNull);
    });

    test('should accept subdomain with port', () {
      final result =
          FormValidator.validateHostPortField('api.example.com:8080');
      expect(result, isNull);
    });
  });
}
