import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/config_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_delete_dialog.dart';

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
}
