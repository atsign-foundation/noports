import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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

  Future<bool> saveAtKeysToPath({
    required Atsign atsign,
    required AtKeys atKeys,
    required String dialogTitle,
    required String fileName,
  }) async {
    final String? defaultDir = await _defaultAtKeysDir();

    String? outputFile = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      initialDirectory: defaultDir,
    );
    if (outputFile == null) return false;

    // FileAtKeysIo writes via a .tmp sibling then renames. macOS sandbox
    // only grants access to the exact user-selected path, so the .tmp
    // write is blocked. Write to the app's own sandbox first, then copy.
    final tempDir = await getApplicationSupportDirectory();
    final tempPath = p.join(tempDir.path, fileName);
    final tempFile = File(tempPath);
    try {
      if (await tempFile.exists()) await tempFile.delete();
      await FileAtKeysIo(filePath: (_) => tempPath).write(atsign, atKeys);

      final destFile = File(outputFile);
      if (await destFile.exists()) await destFile.delete();
      await tempFile.copy(outputFile);
      return true;
    } finally {
      if (await tempFile.exists()) await tempFile.delete();
    }
  }

  static Future<String?> _defaultAtKeysDir() async {
    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null) return null;
    final Directory dir = Directory(p.join(home, '.atsign', 'keys'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }
}
