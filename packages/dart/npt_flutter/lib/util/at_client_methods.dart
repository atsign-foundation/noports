// ignore_for_file: deprecated_member_use
import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:npt_flutter/util/constants.dart';
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
      serviceFactory: _NoSyncAtServiceFactory(),
      enrollmentId: response.enrollmentId,
      atChops: response.atChops,
      atLookUp: response.atLookUp,
    );
  }
}

class _NoSyncAtServiceFactory extends DefaultAtServiceFactory {
  @override
  Future<SyncService> syncService(
    AtClient atClient,
    AtClientManager atClientManager,
    NotificationService notificationService,
  ) async {
    return _NoOpSyncService();
  }
}

class _NoOpSyncService implements SyncService {
  @override
  void sync({Function? onDone, Function? onError}) {}

  @override
  void setOnDone(Function onDone) {}

  @override
  Future<bool> isInSync() async => true;

  @override
  bool get isSyncInProgress => false;

  @override
  void addProgressListener(SyncProgressListener listener) {}

  @override
  void removeProgressListener(SyncProgressListener listener) {}

  @override
  void removeAllProgressListeners() {}
}
