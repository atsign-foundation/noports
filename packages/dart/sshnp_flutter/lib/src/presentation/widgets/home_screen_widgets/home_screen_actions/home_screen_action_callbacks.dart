import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:sshnp_flutter/src/controllers/config_controller.dart';
import 'package:sshnp_flutter/src/presentation/widgets/home_screen_widgets/home_screen_actions/home_screen_import_dialog.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/custom_snack_bar.dart';
import 'package:sshnp_flutter/src/presentation/widgets/utility/responsive_widget.dart';
import 'package:sshnp_flutter/src/utility/constants.dart';

import '../../../../controllers/navigation_controller.dart';

class HomeScreenActionCallbacks {
  static Future<void> import(WidgetRef ref, BuildContext context) async {
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      return _importDesktop(ref, context);
    }
    CustomSnackBar.error(content: 'Unable to import profile:\nUnsupported platform');
  }

  static Future<void> _importDesktop(WidgetRef ref, BuildContext context) async {
    try {
      final XFile? file = await openFile(acceptedTypeGroups: <XTypeGroup>[dotEnvTypeGroup]);
      if (file == null) return;
      if (context.mounted) {
        String initialName = ConfigFileRepository.toProfileName(file.path);
        String? profileName = await _getProfileNameFromUser(context, initialName: initialName);
        if (profileName == null) return;
        if (profileName.isEmpty) profileName = initialName;
        final lines = (await file.readAsString()).split('\n');
        ref
            .read(configFamilyController(profileName).notifier)
            .putConfig(SshnpParams.fromConfigLines(profileName, lines));
      }
    } catch (e) {
      CustomSnackBar.error(content: 'Unable to import profile:\n${e.toString()}');
    }
  }

  static Future<String?> _getProfileNameFromUser(BuildContext context, {String? initialName}) async {
    String? profileName;
    setProfileName(String? p) => profileName = p;
    await showDialog(
      context: context,
      builder: (_) => HomeScreenImportDialog(setProfileName, initialName: initialName),
    );
    return profileName;
  }

  static void newProfileAction(WidgetRef ref, BuildContext context) {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(currentConfigController.notifier).setState(
          CurrentConfigState(
            profileName: 'a',
            configFileWriteState: ConfigFileWriteState.create,
          ),
        );

    if (ResponsiveWidget.isSmallScreen(context)) {
      context.goNamed(
        AppRoute.profileForm.name,
      );
    } else {
      context.replaceNamed(
        AppRoute.profileForm.name,
      );
    }
  }
}
