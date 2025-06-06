import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/widgets/backup_key_alert_dialog.dart';

import '../../../app.dart';
import '../cubit/backup_key_cubit.dart';

class BackupKeyUtils {
  /// This method checks if the backup key has been backed up.
  /// If it has not been backed up, it shows a dialog to the user.
  /// If the backup key has already been backed up, it does nothing.
  Future<void> BackupKeyStatusCheck() async {
    final context = App.navState.currentContext!;

    final backupKeyCubit = context.read<BackupKeyCubit>();
    final keyAlreadyBackedUp = await backupKeyCubit.getBackupKeyStatus();
    if (keyAlreadyBackedUp == false && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (context) => const BackupKeyAlertDialog(),
      );
    }
  }
}
