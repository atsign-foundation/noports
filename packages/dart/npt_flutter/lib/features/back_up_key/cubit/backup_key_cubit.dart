import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:at_backupkey_flutter/services/backupkey_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/back_up_key/repository/backup_key_repository.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';

class BackupKeyCubit extends Cubit<bool> {
  BackupKeyCubit() : super(true);
  //
  Future<bool> getBackupKeyStatus() async {
    final result = await BackUpKeyRepository().getBackupKeyStatus();
    emit(result);
    App.log('BackupKeyCubit: getBackupKeyStatus: $result'.loggable);
    return result;
  }

  Future<void> putBackupKeyStatus(bool status) async {
    log('putBackupKeyStatus: $status');
    final result = await BackUpKeyRepository().putBackupKeyStatus(status);
    emit(result);
    App.log('BackupKeyCubit: getShouldBackupKeyStatus: $result'.loggable);
  }

  void setBackupKeyStatus(bool status) {
    emit(status);
  }

  Future<void> backUpKeys() async {
    final context = App.navState.currentContext!;
    final strings = AppLocalizations.of(context)!;
    var atsign = context.read<OnboardingCubit>().getAtSign();
    // Build file data
    var aesEncryptedKeys = await BackUpKeyService.getEncryptedKeys(atsign);
    var keyString = jsonEncode(aesEncryptedKeys);
    final List<int> codeUnits = keyString.codeUnits;
    final Uint8List data = Uint8List.fromList(codeUnits);

    try {
      final result = await BackUpKeyRepository().saveAtKeysToPath(
        data: data,
        dialogTitle: strings.backupKeyDialogTitle,
        fileName: '${atsign}_key.atKeys',
      );
      if (result) {
        await putBackupKeyStatus(result);
        CustomSnackBar.success(content: strings.fileSaved);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      } else {}
    } catch (e) {
      if (!context.mounted) return;
      CustomSnackBar.error(content: strings.errorAtKeySaveFailed(e.toString()), duration: const Duration(seconds: 10));
    }
  }
}
