import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/util/form_validator.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  Widget createApp() {
    return MaterialApp(
      navigatorKey: App.navState,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Container()),
    );
  }

  group('validateHostPortField', () {
    testWidgets('should accept valid localhost with port', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:8080');
      expect(result, isNull);
    });

    testWidgets('should accept valid IPv4 address with port', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('127.0.0.1:443');
      expect(result, isNull);
    });

    testWidgets('should accept valid IPv6 loopback with port (::1:443)',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('::1:443');
      expect(result, isNull);
    });

    testWidgets('should accept valid IPv6 address with port (fe80::1:8080)',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('fe80::1:8080');
      expect(result, isNull);
    });

    testWidgets('should accept valid full IPv6 address with port',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField(
          '2001:0db8:85a3::8a2e:0370:7334:22');
      expect(result, isNull);
    });

    testWidgets('should accept wildcard host with wildcard port (*:*)',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('*:*');
      expect(result, isNull);
    });

    testWidgets('should accept localhost with wildcard port (localhost:*)',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:*');
      expect(result, isNull);
    });

    testWidgets('should accept IPv6 with wildcard port (::1:*)',
        (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('::1:*');
      expect(result, isNull);
    });

    testWidgets('should accept minimum port number (1)', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:1');
      expect(result, isNull);
    });

    testWidgets('should accept maximum port number (65535)', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:65535');
      expect(result, isNull);
    });

    testWidgets('should reject empty value', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('');
      expect(result, isNotNull);
      expect(result, contains('field'));
    });

    testWidgets('should reject null value', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField(null);
      expect(result, isNotNull);
      expect(result, contains('field'));
    });

    testWidgets('should reject value without colon', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost8080');
      expect(result, isNotNull);
      expect(result, contains('colon'));
    });

    testWidgets('should reject empty host with port (:8080)', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField(':8080');
      expect(result, isNotNull);
      expect(result, contains('Host part cannot be empty'));
    });

    testWidgets('should reject host without port (localhost:)', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:');
      expect(result, isNotNull);
      expect(result, contains('Port part cannot be empty'));
    });

    testWidgets('should reject invalid port (non-numeric)', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:abc');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    testWidgets('should reject port 0', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:0');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    testWidgets('should reject port above 65535', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:65536');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    testWidgets('should reject negative port', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('localhost:-1');
      expect(result, isNotNull);
      expect(result, contains('Port must be a valid number'));
    });

    testWidgets('should accept hostname with hyphens', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('my-host-name:8080');
      expect(result, isNull);
    });

    testWidgets('should accept FQDN with port', (tester) async {
      await tester.pumpWidget(createApp());
      final result = FormValidator.validateHostPortField('example.com:443');
      expect(result, isNull);
    });

    testWidgets('should accept subdomain with port', (tester) async {
      await tester.pumpWidget(createApp());
      final result =
          FormValidator.validateHostPortField('api.example.com:8080');
      expect(result, isNull);
    });
  });
}
