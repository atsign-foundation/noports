import 'dart:convert';
import 'dart:developer';

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
  // TODO: Update so It works for single activation as well as multi activation. Currently, it only works for single activation because it gets the atKeys for the current atsign. We need to update it to get the atKeys for all activated atsigns and save them to separate files and only show the file picker dialog once to the user.
  Future<bool> saveAtKeysToPath({
    // required Uint8List data,
    required Atsign atsign,
    required AtKeys atKeys,
    required String dialogTitle,
  }) async {
    // Get file path to write to
    String? outputFile = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: '${atsign}_key.atKeys',
    );
    if (outputFile == null) return false;
    // Create and write the file
    try {
      FileAtKeysIo atKeysIo = FileAtKeysIo(
        // filePath: (_) => '/path/to/${atsign}_key.atKeys',
        filePath: (_) => outputFile,
      );
      atKeysIo.write(atsign, atKeys);
      // var f = File(outputFile);
      // await f.create(recursive: true);
      // await f.writeAsBytes(data);
      return true;
    } catch (e) {
      rethrow;
    }
  }
}
