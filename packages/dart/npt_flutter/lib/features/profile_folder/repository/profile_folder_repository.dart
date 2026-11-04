import 'dart:async';
import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_folder/models/profile_folder.dart';
import 'package:npt_flutter/util/constants.dart';

class ProfileFolderRepository {
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
      final AtValue value = await _client.get(key);
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
    }
    return true;
  }

  /// Calls [onSynced] after each sync round, or with [caughtUpOnly] only once
  /// nothing is left to push.
  void watchSync(void Function() onSynced, {bool caughtUpOnly = false}) {
    stopWatching();
    try {
      final SyncService syncService = _client.syncService;
      final SyncProgressListener listener = _SyncRoundListener(
        onSynced,
        caughtUpOnly,
      );
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
      return await _client.put(key, jsonEncode(data.toJson()));
    } catch (e) {
      App.log('[ERROR] putProfileFolders: $e'.loggable);
      return false;
    }
  }
}

class _SyncRoundListener extends SyncProgressListener {
  final void Function() onSynced;
  final bool caughtUpOnly;

  _SyncRoundListener(this.onSynced, this.caughtUpOnly);

  @override
  void onSyncProgressEvent(SyncProgress syncProgress) {
    final SyncStatus? status = syncProgress.syncStatus;
    if (caughtUpOnly) {
      if (status == SyncStatus.success &&
          (syncProgress.pendingPushCount ?? 0) == 0) {
        onSynced();
      }
      return;
    }
    // A failed round may still have pulled the folders, so every round counts.
    if (status == SyncStatus.success || status == SyncStatus.failure) {
      onSynced();
    }
  }
}
