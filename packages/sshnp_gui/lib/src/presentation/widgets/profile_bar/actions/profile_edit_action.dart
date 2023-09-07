import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/nav_index_controller.dart';
import 'package:sshnp_gui/src/controllers/sshnp_params_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';
import 'package:sshnp_gui/src/utils/enum.dart';

class ProfileEditAction extends ConsumerStatefulWidget {
  final SSHNPParams params;
  const ProfileEditAction(this.params, {Key? key}) : super(key: key);

  @override
  ConsumerState<ProfileEditAction> createState() => _ProfileEditActionState();
}

class _ProfileEditActionState extends ConsumerState<ProfileEditAction> {
  void onPressed() {
    // Change value to update to trigger the update functionality on the new connection form.
    ref.watch(sshnpParamsController.notifier).setState(
          CurrentSSHNPParamsModel(
            profileName: widget.params.profileName!,
            configFileWriteState: ConfigFileWriteState.update,
          ),
        );
    // change value to 1 to update navigation rail selcted icon.
    ref.watch(navIndexProvider.notifier).goTo(AppRoute.profileForm);
    context.replaceNamed(
      AppRoute.profileForm.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () {
        onPressed();
      },
      icon: const Icon(Icons.edit),
    );
  }
}
