import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_delete_dialog.dart';
import 'package:sshnp_gui/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:path/path.dart' as path;
import 'package:sshnp_gui/src/utility/constants.dart';

class ProfileActionCallbacks {
  static void edit(WidgetRef ref, BuildContext context, String profileName) {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(currentConfigController.notifier).setState(
          CurrentConfigState(
            profileName: profileName,
            configFileWriteState: ConfigFileWriteState.update,
          ),
        );
    context.replaceNamed(
      AppRoute.profileForm.name,
    );
  }

  static void delete(BuildContext context, String profileName) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => ProfileDeleteDialog(profileName: profileName),
    );
  }

  static Future<void> export(
      WidgetRef ref, BuildContext context, String profileName) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return _exportDesktop(ref, context, profileName);
    }
    CustomSnackBar.error(
        content: 'Unable to export profile:\nUnsupported platform');
  }

  static Future<void> _exportDesktop(
      WidgetRef ref, BuildContext context, String profileName) async {
    try {
      final suggestedName = await ConfigFileRepository.fromProfileName(
          profileName,
          basenameOnly: true);
      final initialDirectory =
          getDefaultSshnpConfigDirectory(await getHomeDirectory());

      final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: suggestedName,
        initialDirectory: initialDirectory,
        acceptedTypeGroups: [dotEnvTypeGroup],
      );
      if (saveLocation == null) return;
      final params = ref.read(configFamilyController(profileName));
      final fileData =
          Uint8List.fromList(params.requireValue.toConfig().codeUnits);
      final XFile textFile = XFile.fromData(
        fileData,
        mimeType: dotEnvMimeType,
        name: path.basename(saveLocation.path),
      );

      await textFile.saveTo(saveLocation.path);
    } catch (e) {
      CustomSnackBar.error(
          content: 'Unable to export profile:\n${e.toString()}');
    }
  }
}
