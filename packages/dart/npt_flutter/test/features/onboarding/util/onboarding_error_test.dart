import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';

void main() {
  final AppLocalizationsEn strings = AppLocalizationsEn();

  group('onboardingErrorDetail', () {
    test('unwraps AtException to its message', () {
      expect(
        onboardingErrorDetail(AtException('something specific went wrong')),
        equals('something specific went wrong'),
      );
    });

    test('strips the Exception: prefix from a plain exception', () {
      expect(
        onboardingErrorDetail(Exception('plain failure')),
        equals('plain failure'),
      );
    });
  });

  group('describeOnboardingError', () {
    test('names the stale-keys conflict', () {
      // The exact throw from at_auth when keys already exist locally.
      final error = AtAuthenticationException(
        'atSign: @alice is already onboarded. Cannot perform onboarding again.',
      );
      expect(
        describeOnboardingError(error, strings),
        equals(strings.errorActivationKeysConflict),
      );
    });

    test('names a rejected CRAM secret', () {
      final error = AtAuthenticationException(
        'Cram authentication failed. Please check the cram key and try again',
      );
      expect(
        describeOnboardingError(error, strings),
        equals(strings.errorCramAuthFailed),
      );
    });

    test('names an atsign missing from the atDirectory', () {
      expect(
        describeOnboardingError(
          SecondaryNotFoundException('No entry in atDirectory for alice'),
          strings,
        ),
        equals(strings.errorAtsignNotExist),
      );
    });

    test('names a timeout', () {
      expect(
        describeOnboardingError(AtTimeoutException('Timed out'), strings),
        equals(strings.errorAuthenticationTimedOut),
      );
    });

    test('names a root server connectivity failure', () {
      expect(
        describeOnboardingError(
          RootServerConnectivityException('connect failed'),
          strings,
        ),
        equals(strings.errorAtServerUnreachable),
      );
    });

    test('surfaces an unrecognised cause instead of hiding it', () {
      final String result = describeOnboardingError(
        AtException('the atServer said no for reasons unknown'),
        strings,
      );
      expect(result, contains('the atServer said no for reasons unknown'));
    });

    test('falls back to a generic message when there is no error', () {
      expect(
        describeOnboardingError(null, strings),
        equals(strings.onboardingError),
      );
    });
  });
}
