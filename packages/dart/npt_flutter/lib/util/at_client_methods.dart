import 'package:at_client_flutter/at_client_flutter.dart';
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

  /// The client the app is using, or null before one has been adopted.
  static AtClient? currentClientOrNull() {
    try {
      return AtClientManager.getInstance().atClient;
    } on StateError {
      return null;
    }
  }

  /// Stops the client the app is using, if any. Opening an atsign whose
  /// client is still live is refused, so every sign in stops the previous
  /// client first.
  static Future<void> stopCurrentClient() async {
    await currentClientOrNull()?.stop();
  }

  /// Makes [client] the one the rest of the app uses.
  static void adopt(AtClient client) {
    AtClientManager.getInstance().use(client);
  }

  /// Opens a client for [atsign] on [keys] and adopts it, stopping the
  /// previous client first. The client comes back offline as readily as
  /// online; `client.connection.current` says which, and whether the
  /// atServer refused the keys.
  static Future<AtClient> openAndAdopt({
    required Atsign atsign,
    required AtKeysIo keys,
    required String rootDomain,
  }) async {
    await stopCurrentClient();
    final client = await atsign.open(
      keys: keys,
      preference: await loadAtClientPreference(rootDomain),
      serviceFactory: _NoSyncAtServiceFactory(),
    );
    adopt(client);
    return client;
  }
}

/// Builds clients that never sync, since the app reads and writes the
/// atServer directly.
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
