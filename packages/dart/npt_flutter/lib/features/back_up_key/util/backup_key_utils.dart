import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/back_up_key/widgets/backup_key_alert_dialog.dart';

import '../../../app.dart';
import '../cubit/backup_key_cubit.dart';

class BackupKeyUtils {
  // This method checks if the backing up of key is needed and shows a dialog if necessary.
  Future<void> BackupKeyStatusCheck() async {
    final context = App.navState.currentContext!;

    final backupKeyCubit = context.read<BackupKeyCubit>();
    final keyAlreadyBackedup = await backupKeyCubit.getBackupKeyStatus();
    if (keyAlreadyBackedup == false && context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.2),
        builder: (context) => const BackupKeyAlertDialog(),
      );
    }
  }
}
