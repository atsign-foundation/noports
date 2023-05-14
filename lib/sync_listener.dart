// atPlatform packages
import 'package:at_client/at_client.dart';

class MySyncProgressListener extends SyncProgressListener {
  bool syncComplete = false;

  @override
  void onSyncProgressEvent(SyncProgress syncProgress) {
    if (syncProgress.syncStatus == SyncStatus.failure ||
        syncProgress.syncStatus == SyncStatus.success) {
      syncComplete = true;
    }
    return;
  }
}