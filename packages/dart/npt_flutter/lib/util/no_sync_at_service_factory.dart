import 'package:at_client/at_client.dart';

class NoSyncAtServiceFactory extends DefaultAtServiceFactory {
  @override
  Future<SyncService> syncService(
    AtClient atClient,
    AtClientManager atClientManager,
    NotificationService notificationService,
  ) async {
    return NoOpSyncService();
  }
}

class NoOpSyncService implements SyncService {
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
