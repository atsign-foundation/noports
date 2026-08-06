// ignore_for_file: deprecated_member_use
import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:path_provider/path_provider.dart';

class AtClientMethods {
  static Future<AtClientPreference> loadAtClientPreference(
    String rootDomain,
  ) async {
    var dir = await getApplicationSupportDirectory();

    return AtClientPreference()
      ..rootDomain = rootDomain
      ..namespace = Constants.namespace
      ..hiveStoragePath = dir.path
      ..commitLogPath = dir.path
      ..isLocalStoreRequired = true;
  }

  /// Sets up the AtClient singleton from a completed auth flow (CRAM onboard,
  /// keychain/atKeys PKAM, or post-APKAM PKAM). `AuthResponse.atChops`/
  /// `.atLookUp` are deprecated in favour of `AtAuthSession`, but the resolved
  /// at_client here predates `AtClientManager.fromAuthSession`, so this is the
  /// one place those deprecated fields are read.
  static Future<void> activateFromAuthResponse(
    AuthResponse response,
    String rootDomain,
  ) async {
    final acp = await loadAtClientPreference(rootDomain);
    await AtClientManager.getInstance().setCurrentAtSign(
      response.atSign,
      Constants.namespace,
      acp,
      enrollmentId: response.enrollmentId,
      atChops: response.atChops,
      atLookUp: response.atLookUp,
    );
  }
}
