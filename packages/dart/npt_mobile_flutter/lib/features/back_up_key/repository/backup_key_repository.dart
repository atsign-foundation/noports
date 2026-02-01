import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:file_picker/file_picker.dart';
import 'package:npt_mobile_flutter/app.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class BackUpKeyRepository {
  bool _fromJson(Map<String, dynamic> json) => json['status'];
  Map<String, dynamic> _toJson(bool status) => {'status': status};

  /// This method is used to get the backup key status from the atClient.
  /// If it is already backed up or if there is an error, it returns true, if not, it returns false.
  Future<bool> getBackupKeyStatus() async {
    try {
      AtClient? atClient = AtClientManager.getInstance().atClient;
      if (atClient == null) {
        App.log(
          '[INFO] atClient is null, returning default backup status true'
              .loggable,
        );
        return true;
      }

      String? atSign = atClient.getCurrentAtSign();
      var key = AtKey.self(
        'key_backup.app_metadata',
        namespace: Constants.namespace,
      );
      if (atSign != null) key.sharedBy(atSign);

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
    try {
      AtClient? atClient = AtClientManager.getInstance().atClient;
      if (atClient == null) {
        App.log('[INFO] atClient is null, cannot save backup status'.loggable);
        return false;
      }

      String? atSign = atClient.getCurrentAtSign();
      var key = AtKey.self(
        'key_backup.app_metadata',
        namespace: Constants.namespace,
      );
      if (atSign != null) key.sharedBy(atSign);

      return await atClient.put(key.build(), jsonEncode(_toJson(status)));
    } catch (e) {
      App.log('[ERROR] getbackupKeyStatus() failed: $e'.loggable);
      return false;
    }
  }

  /// This method is used to save the atKeys to a file.
  /// On mobile platforms (iOS/Android), it saves to a temporary directory and uses the share sheet.
  /// On other platforms, it uses the file picker to save directly.
  Future<bool> saveAtKeysToPath({
    required Uint8List data,
    required String dialogTitle,
    required String fileName,
  }) async {
    try {
      // Check if we're on a mobile platform
      if (Platform.isIOS || Platform.isAndroid) {
        // Mobile: Save to temp directory and share
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(data);

        // Share the file using the native share sheet
        final result = await Share.shareXFiles([
          XFile(file.path),
        ], subject: 'Backup atKeys');

        // Consider it successful if the user didn't cancel
        return result.status != ShareResultStatus.dismissed;
      } else {
        // Desktop: Use file picker
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
          fileName: fileName,
        );
        if (outputFile == null) return false;

        var f = File(outputFile);
        await f.create(recursive: true);
        await f.writeAsBytes(data);
        return true;
      }
    } catch (e) {
      App.log('[ERROR] saveAtKeysToPath() failed: $e'.loggable);
      rethrow;
    }
  }
}
