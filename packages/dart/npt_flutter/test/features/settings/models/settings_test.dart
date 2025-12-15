import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/util/language.dart';

void main() {
  group('Settings Model Tests', () {
    group('Constructor', () {
      test('should create Settings with all parameters', () {
        const settings = Settings(
          relayAtsign: '@rv_am',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );

        expect(settings.relayAtsign, '@rv_am');
        expect(settings.overrideRelay, false);
        expect(settings.viewLayout, PreferredViewLayout.minimal);
        expect(settings.darkMode, false);
        expect(settings.language, Language.english);
      });

      test('should create Settings with darkMode defaulting to false', () {
        const settings = Settings(
          relayAtsign: '@rv_eu',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          language: Language.spanish,
        );

        expect(settings.darkMode, false);
      });
    });

    group('copyWith', () {
      late Settings originalSettings;

      setUp(() {
        originalSettings = const Settings(
          relayAtsign: '@rv_am',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );
      });

      test('should return same instance when no parameters provided', () {
        final copiedSettings = originalSettings.copyWith();

        expect(copiedSettings.relayAtsign, originalSettings.relayAtsign);
        expect(copiedSettings.overrideRelay, originalSettings.overrideRelay);
        expect(copiedSettings.viewLayout, originalSettings.viewLayout);
        expect(copiedSettings.darkMode, originalSettings.darkMode);
        expect(copiedSettings.language, originalSettings.language);
      });

      test('should update relayAtsign when provided', () {
        final copiedSettings = originalSettings.copyWith(relayAtsign: '@rv_eu');

        expect(copiedSettings.relayAtsign, '@rv_eu');
        expect(copiedSettings.overrideRelay, originalSettings.overrideRelay);
        expect(copiedSettings.viewLayout, originalSettings.viewLayout);
        expect(copiedSettings.darkMode, originalSettings.darkMode);
        expect(copiedSettings.language, originalSettings.language);
      });

      test('should default to @rv_am when relayAtsign is null or empty', () {
        final copiedWithNull = originalSettings.copyWith(relayAtsign: null);
        final copiedWithEmpty = originalSettings.copyWith(relayAtsign: '');

        expect(copiedWithNull.relayAtsign, '@rv_am');
        expect(copiedWithEmpty.relayAtsign, '@rv_am');
      });

      test('should update overrideRelay when provided', () {
        final copiedSettings = originalSettings.copyWith(overrideRelay: true);

        expect(copiedSettings.overrideRelay, true);
        expect(copiedSettings.relayAtsign, originalSettings.relayAtsign);
      });

      test('should update viewLayout when provided', () {
        final copiedSettings = originalSettings.copyWith(
          viewLayout: PreferredViewLayout.sshStyle,
        );

        expect(copiedSettings.viewLayout, PreferredViewLayout.sshStyle);
        expect(copiedSettings.relayAtsign, originalSettings.relayAtsign);
      });

      test('should update darkMode when provided', () {
        final copiedSettings = originalSettings.copyWith(darkMode: true);

        expect(copiedSettings.darkMode, true);
        expect(copiedSettings.relayAtsign, originalSettings.relayAtsign);
      });

      test('should update language when provided', () {
        final copiedSettings = originalSettings.copyWith(
          language: Language.spanish,
        );

        expect(copiedSettings.language, Language.spanish);
        expect(copiedSettings.relayAtsign, originalSettings.relayAtsign);
      });

      test('should update multiple properties at once', () {
        final copiedSettings = originalSettings.copyWith(
          relayAtsign: '@rv_ap',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: true,
          language: Language.mandarin,
        );

        expect(copiedSettings.relayAtsign, '@rv_ap');
        expect(copiedSettings.overrideRelay, true);
        expect(copiedSettings.viewLayout, PreferredViewLayout.sshStyle);
        expect(copiedSettings.darkMode, true);
        expect(copiedSettings.language, Language.mandarin);
      });
    });

    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        const settings = Settings(
          relayAtsign: '@rv_eu',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: true,
          language: Language.portuguese,
        );

        final json = settings.toJson();

        expect(json['relayAtsign'], '@rv_eu');
        expect(json['overrideRelay'], true);
        expect(json['viewLayout'], 'ssh-style');
        expect(json['darkMode'], true);
        expect(json['language'], 'pt-br');
      });

      test('should deserialize from JSON correctly', () {
        final json = {
          'relayAtsign': '@rv_ap',
          'overrideRelay': false,
          'viewLayout': 'minimal',
          'darkMode': false,
          'language': 'zh-hans-cn',
        };

        final settings = Settings.fromJson(json);

        expect(settings.relayAtsign, '@rv_ap');
        expect(settings.overrideRelay, false);
        expect(settings.viewLayout, PreferredViewLayout.minimal);
        expect(settings.darkMode, false);
        expect(settings.language, Language.mandarin);
      });

      test('should handle round-trip serialization', () {
        const originalSettings = Settings(
          relayAtsign: '@custom_relay',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: true,
          language: Language.cantonese,
        );

        final json = originalSettings.toJson();
        final deserializedSettings = Settings.fromJson(json);

        expect(deserializedSettings.relayAtsign, originalSettings.relayAtsign);
        expect(
          deserializedSettings.overrideRelay,
          originalSettings.overrideRelay,
        );
        expect(deserializedSettings.viewLayout, originalSettings.viewLayout);
        expect(deserializedSettings.darkMode, originalSettings.darkMode);
        expect(deserializedSettings.language, originalSettings.language);
      });
    });

    group('Equality and Props', () {
      test('should be equal when all properties are the same', () {
        const settings1 = Settings(
          relayAtsign: '@rv_am',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );

        const settings2 = Settings(
          relayAtsign: '@rv_am',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );

        expect(settings1, equals(settings2));
        expect(settings1.hashCode, equals(settings2.hashCode));
      });

      test('should not be equal when properties differ', () {
        const settings1 = Settings(
          relayAtsign: '@rv_am',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );

        const settings2 = Settings(
          relayAtsign: '@rv_eu',
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          darkMode: false,
          language: Language.english,
        );

        expect(settings1, isNot(equals(settings2)));
      });

      test('should have correct props list', () {
        const settings = Settings(
          relayAtsign: '@rv_am',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: true,
          language: Language.spanish,
        );

        final props = settings.props;

        expect(props, hasLength(6));
        expect(props[0], '@rv_am');
        expect(props[1], true);
        expect(props[2], PreferredViewLayout.sshStyle);
        expect(props[3], true);
        expect(props[4], Language.spanish);
        expect(
          props[5],
          true,
        ); // In Settings constructor: this.pinFavorites = true
        // So props[5] should be true by default.
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        const settings = Settings(
          relayAtsign: '@rv_eu',
          overrideRelay: true,
          viewLayout: PreferredViewLayout.sshStyle,
          darkMode: false,
          language: Language.portuguese,
        );

        final stringRepresentation = settings.toString();

        expect(stringRepresentation, contains('Settings with relay:@rv_eu'));
        expect(stringRepresentation, contains('overrideRelay: true'));
        expect(
          stringRepresentation,
          contains('view: PreferredViewLayout.sshStyle'),
        );
        expect(stringRepresentation, contains('darkMode: false'));
        expect(stringRepresentation, contains('lang: pt-br'));
      });
    });

    group('Constants', () {
      test('should have correct customRelayKey constant', () {
        expect(Settings.customRelayKey, 'custom');
      });
    });
  });

  group('PreferredViewLayout Enum Tests', () {
    test('should have correct display names', () {
      expect(PreferredViewLayout.minimal.displayName, 'Simple');
      expect(PreferredViewLayout.sshStyle.displayName, 'Advanced');
    });

    test('should serialize with kebab-case field names', () {
      const settings1 = Settings(
        relayAtsign: '@rv_am',
        overrideRelay: false,
        viewLayout: PreferredViewLayout.minimal,
        language: Language.english,
      );

      const settings2 = Settings(
        relayAtsign: '@rv_am',
        overrideRelay: false,
        viewLayout: PreferredViewLayout.sshStyle,
        language: Language.english,
      );

      final json1 = settings1.toJson();
      final json2 = settings2.toJson();

      expect(json1['viewLayout'], 'minimal');
      expect(json2['viewLayout'], 'ssh-style');
    });
  });

  group('RelayOptions Extension Tests', () {
    test('should return correct relay atsign for each option', () {
      expect(RelayOptions.am.relayAtsign, '@rv_am');
      expect(RelayOptions.eu.relayAtsign, '@rv_eu');
      expect(RelayOptions.ap.relayAtsign, '@rv_ap');
    });

    test(
      'should have regions property (requires app context for localization)',
      () {
        // Note: Testing regions requires app context for AppLocalizations
        // This would typically be tested in widget tests or integration tests
        // where the app context is available
        expect(RelayOptions.values, hasLength(3));
        expect(RelayOptions.values, contains(RelayOptions.am));
        expect(RelayOptions.values, contains(RelayOptions.eu));
        expect(RelayOptions.values, contains(RelayOptions.ap));
      },
    );
  });
}
