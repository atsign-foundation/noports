import 'package:at_auth/at_auth.dart';
import 'package:at_chops/at_chops.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:at_lookup/at_lookup.dart';
import 'package:npt_flutter/util/constants.dart';

/// Brings up an [AtClient] for [atsign] and makes it the current one.
///
/// at_onboarding_flutter's `AtOnboarding.onboard` did this implicitly; the
/// at_client_flutter auth primitives only perform PKAM/APKAM and hand back the
/// keys, so every successful auth path has to do this before anything touches
/// [AtClientManager.atClient].
///
/// Takes the key material directly rather than a response object because PKAM
/// returns an [AuthResponse] while APKAM returns an [AtEnrollmentResponse], and
/// the two are unrelated types.
Future<void> activateAtClient({
  required String atsign,
  required AtClientPreference atClientPreference,
  AtKeys? atKeys,
  AtChops? atChops,
  AtLookUp? atLookUp,
  String? enrollmentId,
}) async {
  await AtClientManager.getInstance().setCurrentAtSign(
    atsign,
    Constants.namespace,
    atClientPreference,
    atChops: atChops ?? atKeys?.toAtChops(),
    atLookUp: atLookUp,
    enrollmentId: enrollmentId ?? atKeys?.enrollmentId,
  );
}

/// [activateAtClient] for the PKAM/CRAM paths, which return an [AuthResponse].
Future<void> activateAtClientFromAuthResponse({
  required String atsign,
  required AtClientPreference atClientPreference,
  required AuthResponse response,
}) => activateAtClient(
  atsign: atsign,
  atClientPreference: atClientPreference,
  atKeys: response.atAuthKeys,
  atChops: response.atChops,
  atLookUp: response.atLookUp,
  enrollmentId: response.enrollmentId,
);
