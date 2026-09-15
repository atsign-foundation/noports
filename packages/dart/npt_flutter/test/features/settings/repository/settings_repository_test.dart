import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/features/settings/repository/settings_repository.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/language.dart';

// Import the existing mocks from ProfileRepository tests
import '../../profile/repository/profile_repository_test.mocks.dart';

void main() {
  // Initialize the binding for Flutter tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsRepository Tests', () {
    late SettingsRepository repository;
    late MockAtClient mockAtClient;
    late MockAtClientManager mockAtClientManager;

    const testAtsign = '@test_user';
    final testSettings = Settings(
      relayAtsign: '@rv_eu'.toAtsign(),
      overrideRelay: true,
      viewLayout: PreferredViewLayout.sshStyle,
      darkMode: true,
      language: Language.spanish,
    );

    setUp(() {
      mockAtClient = MockAtClient();
      mockAtClientManager = MockAtClientManager();

      // Create repository with injected mock AtClient
      repository = SettingsRepository(atClient: mockAtClient);

      // Mock AtClientManager singleton behavior
      when(mockAtClientManager.atClient).thenReturn(mockAtClient);
      when(mockAtClient.getCurrentAtSign()).thenReturn(testAtsign);
    });

    group('Default Settings', () {
      test('should provide correct default settings', () {
        final defaultSettings = repository.defaultSettings;

        expect(defaultSettings.relayAtsign, equals('@rv_am'));
        expect(defaultSettings.viewLayout, equals(PreferredViewLayout.minimal));
        expect(defaultSettings.overrideRelay, isFalse);
        expect(defaultSettings.darkMode, isFalse);
        // The default language should be based on Platform.localeName
        expect(defaultSettings.language, isA<Language>());
      });

      test('should provide consistent default values', () {
        final defaultSettings1 = repository.defaultSettings;
        final defaultSettings2 = repository.defaultSettings;

        expect(
          defaultSettings1.relayAtsign,
          equals(defaultSettings2.relayAtsign),
        );
        expect(
          defaultSettings1.viewLayout,
          equals(defaultSettings2.viewLayout),
        );
        expect(
          defaultSettings1.overrideRelay,
          equals(defaultSettings2.overrideRelay),
        );
        expect(defaultSettings1.darkMode, equals(defaultSettings2.darkMode));
        expect(defaultSettings1.language, equals(defaultSettings2.language));
      });
    });

    group('AtKey Generation', () {
      test('should generate correct AtKey for settings', () {
        final atKey = repository.settingsAtKey;

        expect(atKey.key, equals('settings'));
        expect(atKey.namespace, equals(Constants.namespace));
        expect(
          atKey.sharedBy,
          equals(''),
        ); // Self key shouldn't have sharedBy initially
      });
    });

    group('CRUD Operations', () {
      group('getSettings', () {
        test('should return settings from AtClient when available', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;
          final atValue = AtValue()..value = jsonEncode(testSettings.toJson());

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getSettings();

          expect(result, isNotNull);
          expect(result!.relayAtsign, equals('@rv_eu'));
          expect(result.overrideRelay, isTrue);
          expect(result.viewLayout, equals(PreferredViewLayout.sshStyle));
          expect(result.darkMode, isTrue);
          expect(result.language, equals(Language.spanish));

          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should return default settings when no settings saved', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;
          final atValue = AtValue()..value = null;

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getSettings();

          expect(result, isNotNull);
          expect(result!.relayAtsign, equals('@rv_am'));
          expect(result.viewLayout, equals(PreferredViewLayout.minimal));
          expect(result.overrideRelay, isFalse);
          expect(result.darkMode, isFalse);
          expect(result.language, isA<Language>());

          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should return null when AtClient throws exception', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenThrow(Exception('Settings not found'));

          final result = await repository.getSettings();

          expect(result, isNull);
          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle JSON decode errors gracefully', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;
          final atValue = AtValue()..value = 'invalid json';

          when(
            mockAtClient.get(
              atKey,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).thenAnswer((_) async => atValue);

          final result = await repository.getSettings();

          expect(result, isNull);
          verify(
            mockAtClient.get(
              any,
              getRequestOptions: anyNamed('getRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle null atSign gracefully', () async {
          when(mockAtClient.getCurrentAtSign()).thenReturn(null);

          final result = await repository.getSettings();

          expect(result, isNull);
        });
      });

      group('putSettings', () {
        test('should successfully save settings to AtClient', () async {
          final atKey = repository.settingsAtKey;

          when(
            mockAtClient.put(
              atKey,
              jsonEncode(testSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository.putSettings(testSettings);

          expect(result, isTrue);
          verify(
            mockAtClient.put(
              atKey,
              jsonEncode(testSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).called(1);
        });

        test('should return false when AtClient put fails', () async {
          final atKey = repository.settingsAtKey;

          when(
            mockAtClient.put(
              atKey,
              jsonEncode(testSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenThrow(Exception('Put failed'));

          final result = await repository.putSettings(testSettings);

          expect(result, isFalse);
          verify(
            mockAtClient.put(
              atKey,
              jsonEncode(testSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle different settings configurations', () async {
          final darkModeSettings = Settings(
            relayAtsign: '@rv_ap'.toAtsign(),
            overrideRelay: false,
            viewLayout: PreferredViewLayout.minimal,
            darkMode: true,
            language: Language.mandarin,
          );

          final atKey = repository.settingsAtKey;

          when(
            mockAtClient.put(
              atKey,
              jsonEncode(darkModeSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository.putSettings(darkModeSettings);

          expect(result, isTrue);
          verify(
            mockAtClient.put(
              atKey,
              jsonEncode(darkModeSettings.toJson()),
              putRequestOptions: anyNamed('putRequestOptions'),
            ),
          ).called(1);
        });
      });

      group('deleteSettings', () {
        test('should successfully delete settings from AtClient', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;

          when(
            mockAtClient.delete(
              atKey,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).thenAnswer((_) async => true);

          final result = await repository.deleteSettings(testSettings);

          expect(result, isTrue);
          verify(
            mockAtClient.delete(
              any,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).called(1);
        });

        test('should return false when AtClient delete fails', () async {
          final atKey = repository.settingsAtKey..sharedBy = testAtsign;

          when(
            mockAtClient.delete(
              atKey,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).thenThrow(Exception('Delete failed'));

          final result = await repository.deleteSettings(testSettings);

          expect(result, isFalse);
          verify(
            mockAtClient.delete(
              any,
              deleteRequestOptions: anyNamed('deleteRequestOptions'),
            ),
          ).called(1);
        });

        test('should handle null atSign gracefully', () async {
          when(mockAtClient.getCurrentAtSign()).thenReturn(null);

          final result = await repository.deleteSettings(testSettings);

          expect(result, isFalse);
        });
      });
    });

    group('Integration with Settings Model', () {
      test('should correctly serialize and deserialize settings', () async {
        final originalSettings = Settings(
          relayAtsign: '@custom_relay'.toAtsign(),
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: false,
          language: Language.portuguese,
        );

        final atKey = repository.settingsAtKey;
        final putAtKey = repository.settingsAtKey..sharedBy = testAtsign;

        // Setup put
        when(
          mockAtClient.put(
            atKey,
            jsonEncode(originalSettings.toJson()),
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        // Setup get
        final atValue = AtValue()
          ..value = jsonEncode(originalSettings.toJson());
        when(
          mockAtClient.get(
            putAtKey,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenAnswer((_) async => atValue);

        // Put settings
        final putResult = await repository.putSettings(originalSettings);
        expect(putResult, isTrue);

        // Get settings back
        final getResult = await repository.getSettings();
        expect(getResult, isNotNull);
        expect(getResult!.relayAtsign, equals('@custom_relay'));
        expect(getResult.overrideRelay, isTrue);
        expect(getResult.viewLayout, equals(PreferredViewLayout.sshStyle));
        expect(getResult.darkMode, isFalse);
        expect(getResult.language, equals(Language.portuguese));
      });
    });

    group('Error Handling and Edge Cases', () {
      test('should handle network errors gracefully', () async {
        when(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(const SocketException('Network error'));

        final getResult = await repository.getSettings();
        expect(getResult, isNull);

        when(
          mockAtClient.put(
            any,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(const SocketException('Network error'));

        final putResult = await repository.putSettings(testSettings);
        expect(putResult, isFalse);

        when(
          mockAtClient.delete(
            any,
            deleteRequestOptions: anyNamed('deleteRequestOptions'),
          ),
        ).thenThrow(const SocketException('Network error'));

        final deleteResult = await repository.deleteSettings(testSettings);
        expect(deleteResult, isFalse);
      });

      test('should handle AtClient timeout errors', () async {
        when(
          mockAtClient.get(
            any,
            getRequestOptions: anyNamed('getRequestOptions'),
          ),
        ).thenThrow(TimeoutException('Request timeout'));

        final getResult = await repository.getSettings();
        expect(getResult, isNull);

        when(
          mockAtClient.put(
            any,
            any,
            putRequestOptions: anyNamed('putRequestOptions'),
          ),
        ).thenThrow(TimeoutException('Request timeout'));

        final putResult = await repository.putSettings(testSettings);
        expect(putResult, isFalse);
      });
    });
  });
}
