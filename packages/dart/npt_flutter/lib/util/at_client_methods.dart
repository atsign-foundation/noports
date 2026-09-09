// ignore_for_file: deprecated_member_use
import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/no_sync_at_service_factory.dart';
import 'package:path_provider/path_provider.dart';

class AtClientMethods {
  static Future<AtClientPreference> loadAtClientPreference(
    String rootDomain,
  ) async {
    final dir = await getApplicationSupportDirectory();
    return AtClientPreference()
      ..rootDomain = rootDomain
      ..namespace = Constants.namespace
      ..hiveStoragePath = dir.path
      ..commitLogPath = dir.path
      ..isLocalStoreRequired = true
      ..remoteLocalPref = RemoteLocalPref.remoteOnly;
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
      serviceFactory: NoSyncAtServiceFactory(),
      enrollmentId: response.enrollmentId,
      atChops: response.atChops,
      atLookUp: response.atLookUp,
    );
  }
}
