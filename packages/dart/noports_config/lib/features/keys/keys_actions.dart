import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:noports_config/features/config/cubit/config_cubit.dart';
import 'package:noports_config/features/keys/keys_repository.dart';
import 'package:noports_config/features/keys/view/enrollment_dialog.dart';
import 'package:noports_config/l10n/app_localizations.dart';
import 'package:noports_config/widgets/custom_snack_bar.dart';

/// The ways of getting device keys onto this machine, shared by the Keys
/// tab and the setup wizard. Both update the working configuration
/// (atSign, device name and keys path); saving is left to the caller.
class KeysActions {
  KeysActions._();

  /// APKAM enrollment approved from NoPorts Desktop. The normal path.
  static Future<String?> enroll(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final config = context.read<ConfigCubit>();
    final doc = config.state.doc;
    final outcome = await EnrollmentDialog.show(
      context,
      rootDomain: doc?.rootDomain ?? 'root.atsign.org',
      initialAtsign: doc?.atsign,
      initialDeviceName: doc?.deviceName ?? 'default',
    );
    if (outcome == null || !context.mounted) return null;
    config.update((d) {
      d.atsign = outcome.atsign;
      d.deviceName = outcome.deviceName;
      d.keysFile = outcome.keysFile.path;
    });
    CustomSnackBar.success(context, strings.enrollSuccess(outcome.atsign));
    return outcome.atsign;
  }

  /// Pick an existing .atKeys file, copy it into the managed directory and
  /// point the config at it. For fleet deployments and recovery.
  static Future<String?> importKeys(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final config = context.read<ConfigCubit>();
    final picked = await FilePicker.pickFiles(
      dialogTitle: strings.importKeys,
      type: FileType.custom,
      allowedExtensions: ['atKeys'],
    );
    final path = picked?.files.single.path;
    if (path == null || !context.mounted) return null;
    final source = File(path);

    final atsign = KeysRepository.atsignOf(source);
    if (atsign == null) {
      CustomSnackBar.error(
        context,
        strings.keysImportFailed('Could not tell which atSign this file is for.'),
      );
      return null;
    }
    final configured = config.state.doc?.atsign;
    if (configured != null && configured != atsign) {
      final useAnyway = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(strings.keysAtsignMismatch(atsign, configured)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(strings.useAnyway),
            ),
          ],
        ),
      );
      if (useAnyway != true || !context.mounted) return null;
    }
    try {
      final dest = await KeysRepository().import(source, atsign);
      config.update((doc) {
        doc.atsign = atsign;
        doc.keysFile = dest.path;
      });
      if (context.mounted) {
        CustomSnackBar.success(context, strings.keysImported(atsign));
      }
      return atsign;
    } catch (e) {
      if (context.mounted) {
        CustomSnackBar.error(context, strings.keysImportFailed(e.toString()));
      }
      return null;
    }
  }
}
