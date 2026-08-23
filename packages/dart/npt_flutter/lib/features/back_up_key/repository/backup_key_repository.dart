import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/util/constants.dart';

class BackUpKeyRepository {
  bool _fromJson(Map<String, dynamic> json) => json['status'];
  Map<String, dynamic> _toJson(bool status) => {'status': status};

  /// This method is used to get the backup key status from the atClient.
  /// If it is already backed up or if there is an error, it returns true, if not, it returns false.
  Future<bool> getBackupKeyStatus() async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    var key = AtKey.self(
      'key_backup.app_metadata',
      namespace: Constants.namespace,
    );
    if (atsign != null) key.sharedBy(atsign);

    try {
      final value = await atClient.get(key.build());
      log('getBackupKeyStatus: ${value.value}');
      return _fromJson(jsonDecode(value.value));
    } catch (e) {
      App.log('[ERROR] getShouldBackupKeyStatus() failed: $e'.loggable);
      return true;
    }
  }

  /// This method is used to update the backup key status in the atClient.
  Future<bool> putBackupKeyStatus(bool status) async {
    AtClient atClient = AtClientManager.getInstance().atClient;
    Atsign? atsign = atClient.getCurrentAtSign()?.toAtsign();
    var key = AtKey.self(
      'key_backup.app_metadata',
      namespace: Constants.namespace,
    );
    if (atsign != null) key.sharedBy(atsign);

    try {
      return await atClient.put(key.build(), jsonEncode(_toJson(status)));
    } catch (e) {
      App.log('[ERROR] getbackupKeyStatus() failed: $e'.loggable);
      return false;
    }
  }

  /// This method is used to save the atKeys to a file.
  Future<bool> saveAtKeysToPath({
    required Atsign atsign,
    required AtKeys atKeys,
    required String dialogTitle,
    required String fileName,
  }) async {
    // Get file path to write to
    String? outputFile = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
    );
    if (outputFile == null) return false;
    try {
      final file = File(outputFile);
      if (await file.exists()) await file.delete();
      await FileAtKeysIo(filePath: (_) => outputFile).write(atsign, atKeys);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
