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
