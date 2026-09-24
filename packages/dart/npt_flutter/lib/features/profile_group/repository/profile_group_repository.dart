import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/profile_group/models/profile_group.dart';
import 'package:npt_flutter/util/constants.dart';

class ProfileGroupRepository {
  final AtClient? _atClient;
  SyncService? _watchedSync;
  SyncProgressListener? _syncListener;

  ProfileGroupRepository({AtClient? atClient}) : _atClient = atClient;

  AtClient get _client => _atClient ?? AtClientManager.getInstance().atClient;

  static AtKey getProfileGroupAtKey({String? sharedBy}) {
    final builder = AtKey.self(
      Constants.profileGroupKeyName,
      namespace: Constants.namespace,
    );
    if (sharedBy != null) builder.sharedBy(sharedBy);
    return builder.build();
  }

  /// Returns the stored groups, an empty [ProfileGroupData] when nothing has
  /// been stored yet, or null when the value could not be read.
  Future<ProfileGroupData?> getProfileGroups() async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileGroupAtKey(sharedBy: atsign);

    try {
      final AtValue value = await _client.get(key);
      if (value.value == null) return const ProfileGroupData();
      final dynamic json = jsonDecode(value.value);
      if (json is! Map) {
        throw 'profile groups from the atServer is not a Map';
      }
      return ProfileGroupData.fromJson(Map<String, dynamic>.from(json));
    } on AtKeyNotFoundException {
      return const ProfileGroupData();
    } on KeyNotFoundException {
      return const ProfileGroupData();
    } catch (e) {
      App.log('[ERROR] getProfileGroups: $e'.loggable);
      return null;
    }
  }

  /// Waits for the local copy to catch up with the atServer, so a device
  /// doesn't show, then save over, folders edited elsewhere. Returns false if
  /// that takes longer than [timeout].
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

  /// Calls [onSynced] after every sync round, which may have pulled a newer
  /// copy of the folders, or with [caughtUpOnly] only after a successful round
  /// that left nothing to push. Replaces any previous watch.
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

  Future<bool> putProfileGroups(ProfileGroupData data) async {
    final Atsign? atsign = _client.getCurrentAtSign()?.toAtsign();
    final AtKey key = getProfileGroupAtKey(sharedBy: atsign);
    try {
      return await _client.put(key, jsonEncode(data.toJson()));
    } catch (e) {
      App.log('[ERROR] putProfileGroups: $e'.loggable);
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
    // A round that pulled the folders and then failed reports them nowhere,
    // so every finished round triggers a re-read.
    if (status == SyncStatus.success || status == SyncStatus.failure) {
      onSynced();
    }
  }
}
