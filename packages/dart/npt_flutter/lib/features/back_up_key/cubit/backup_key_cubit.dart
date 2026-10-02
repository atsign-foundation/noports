import 'dart:developer';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/repository/backup_key_repository.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';

class BackupKeyCubit extends Cubit<bool> {
  BackupKeyCubit()
    : super(
        true,
      ); // Initialize with true to indicate that atKeys are backed up by default.

  /// Retrieves the backup key status from the repository and emits it.
  Future<bool> getBackupKeyStatus() async {
    final result = await BackUpKeyRepository().getBackupKeyStatus();
    emit(result);
    App.log('BackupKeyCubit: getBackupKeyStatus: $result'.loggable);
    return result;
  }

  /// Updates the backup key status in the repository and emits the new status.
  Future<void> putBackupKeyStatus(bool status) async {
    log('putBackupKeyStatus: $status');
    final result = await BackUpKeyRepository().putBackupKeyStatus(status);
    emit(result);
    App.log('BackupKeyCubit: getShouldBackupKeyStatus: $result'.loggable);
  }

  /// Sets the backup key status and emits the new status.
  /// This method is used to set the backup key status in the cubit. It does not save the key to the atServer.
  void setBackupKeyStatus(bool status) {
    emit(status);
  }

  /// This method is used to back up the atKeys to a file.
  /// It encrypts the atKeys using AES encryption and saves them to a file.
  /// It also updates the backup key status in the cubit.
  /// If the backup is successful, it shows a success message.
  /// If the backup fails, it shows an error message.
  /// It also pops the dialog if the backup is successful & [popDialog] is true.
  Future<void> backUpKeys({bool popDialog = true}) async {
    final context = App.navState.currentContext!;
    final strings = AppLocalizations.of(context)!;
    var atsign = context.read<OnboardingCubit>().getAtsign();
    final atKeys = await KeychainStorage().getAtsign(atsign);
    if (atKeys == null) {
      CustomSnackBar.error(
        content: strings.errorAtKeySaveFailed('no keys found for $atsign'),
      );
      return;
    }

    try {
      final result = await BackUpKeyRepository().saveAtKeysToPath(
        atsign: atsign,
        atKeys: atKeys,
        dialogTitle: strings.backupKeyDialogTitle,
        fileName: '${atsign}_key.atKeys',
      );
      if (result) {
        // File saved Successfully
        await putBackupKeyStatus(result);
        CustomSnackBar.success(content: strings.fileSaved);
        App.log('backUpKeys: Backup successful'.loggable);
        if (!context.mounted) return;
        if (popDialog) Navigator.of(context).pop();
      } else {
        // User Cancelled - do nothing
        App.log('Backup cancelled by user'.loggable);
      }
    } catch (e) {
      // Error during file write
      if (!context.mounted) return;
      App.log('[ERROR] backUpKeys() failed: $e'.loggable);
      CustomSnackBar.error(content: strings.errorAtKeySaveFailed(e.toString()));
    }
  }
}
