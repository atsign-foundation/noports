import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

/// Turns an onboarding or authentication failure into a message that names the
/// actual cause.
///
/// [AtOnboardingResponse] carries no error field - at_auth reports every
/// failure by throwing - so the exception is the only place the cause exists.
/// Collapsing it into a flat "Authentication failed." leaves whoever hit it
/// with nothing to act on, so recognised failures get a specific message and
/// everything else is shown verbatim rather than swallowed.
String describeOnboardingError(Object? error, AppLocalizations strings) {
  if (error == null) return strings.onboardingError;

  final String detail = onboardingErrorDetail(error);

  // The atServer rejected the CRAM secret. Nearly always a spent activation
  // file, since each secret is single use.
  if (detail.contains('Cram authentication failed') ||
      detail.contains('cram authentication failed')) {
    return strings.errorCramAuthFailed;
  }

  // AtAuth.onboard refuses to run while keys for this atsign already exist
  // locally, whatever the atServer says.
  if (detail.contains('already onboarded')) {
    return strings.errorActivationKeysConflict;
  }

  if (detail.contains('is already activated') ||
      detail.contains('already been activated')) {
    return strings.errorAtsignActivated;
  }

  if (error is AtTimeoutException || detail.contains('Timed out')) {
    return strings.errorAuthenticationTimedOut;
  }

  if (error is SecondaryNotFoundException ||
      detail.contains('No entry in atDirectory')) {
    return strings.errorAtsignNotExist;
  }

  if (error is RootServerConnectivityException ||
      error is AtConnectException) {
    return strings.errorAtServerUnreachable;
  }

  // Unrecognised: show what actually went wrong instead of hiding it.
  return strings.errorOnboardingWithDetails(detail);
}

/// The human-readable part of [error], without the `Exception: ` noise that
/// [AtException.toString] prepends.
String onboardingErrorDetail(Object error) {
  if (error is AtException) return error.message;

  final String text = error.toString();
  const String prefix = 'Exception: ';
  return text.startsWith(prefix) ? text.substring(prefix.length) : text;
}
