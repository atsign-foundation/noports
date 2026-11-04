import 'dart:async';
import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/util/constants.dart';

/// Every folder is in one document under one key, so when two devices change
/// folders before syncing, the last one to sync wins.
class ProfileFolderRepository {
  /// A read or write that hangs would hold up every later folder event.
  static const Duration _timeout = Duration(seconds: 30);

  final AtClient? _atClient;
  SyncService? _watchedSync;
  SyncProgressListener? _syncListener;

  ProfileFolderRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  static AtKey getProfileFolderAtKey({String? sharedBy}) {
    final builder = AtKey.self(
      Constants.profileFolderKeyName,
      namespace: Constants.namespace,
    );
    if (sharedBy != null) builder.sharedBy(sharedBy);
    return builder.build();
  }

  /// Returns the stored folders, an empty [ProfileFolderData] when nothing has
  /// been stored yet, or null when the value could not be read.
  Future<ProfileFolderData?> getProfileFolders() async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileFolderAtKey(sharedBy: atsign);

    try {
      final AtValue value = await _client.get(key).timeout(_timeout);
      if (value.value == null) return const ProfileFolderData();
      final dynamic json = jsonDecode(value.value);
      if (json is! Map) {
        throw 'profile folders from the atServer is not a Map';
      }
      return ProfileFolderData.fromJson(Map<String, dynamic>.from(json));
    } on AtKeyNotFoundException {
      return const ProfileFolderData();
    } on KeyNotFoundException {
      return const ProfileFolderData();
    } catch (e) {
      App.log('[ERROR] getProfileFolders: $e'.loggable);
      return null;
    }
  }

  /// False if the local copy hasn't caught up with the atServer by [timeout].
  Future<bool> waitForSync({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      await _client.syncService.waitUntilCaughtUp(timeout: timeout);
    } on TimeoutException {
      App.log('[ERROR] waitForSync: timed out after $timeout'.loggable);
      return false;
    } catch (e) {
      App.log('[ERROR] waitForSync: $e'.loggable);
      return false;
    }
    return true;
  }

  /// Calls [onRound] after each sync round, with whether it pulled everything
  /// the atServer had. Pushes still waiting don't count: one the atServer
  /// keeps refusing would otherwise hold the folders read-only.
  void watchSync(void Function(bool caughtUp) onRound) {
    stopWatching();
    try {
      final SyncService syncService = _client.syncService;
      final SyncProgressListener listener = _SyncRoundListener(onRound);
      syncService.addProgressListener(listener);
      _watchedSync = syncService;
      _syncListener = listener;
    } catch (e) {
      App.log('[ERROR] watchSync: $e'.loggable);
    }
  }

  void stopWatching() {
    final SyncProgressListener? listener = _syncListener;
    if (listener != null) _watchedSync?.removeProgressListener(listener);
    _watchedSync = null;
    _syncListener = null;
  }

  Future<bool> putProfileFolders(ProfileFolderData data) async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileFolderAtKey(sharedBy: atsign);
    try {
      return await _client
          .put(key, jsonEncode(data.toJson()))
          .timeout(_timeout);
    } catch (e) {
      App.log('[ERROR] putProfileFolders: $e'.loggable);
      return false;
    }
  }
}

class _SyncRoundListener extends SyncProgressListener {
  final void Function(bool caughtUp) onRound;

  _SyncRoundListener(this.onRound);

  @override
  void onSyncProgressEvent(SyncProgress syncProgress) {
    final SyncStatus? status = syncProgress.syncStatus;
    // A failed round may still have pulled the folders, so every round counts.
    if (status == SyncStatus.success || status == SyncStatus.failure) {
      final int? server = syncProgress.serverCommitId;
      onRound(
        status == SyncStatus.success &&
            (server == null || (syncProgress.localCommitId ?? -1) >= server),
      );
    }
  }
}
