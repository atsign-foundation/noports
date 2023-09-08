import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/controllers/sshnp_params_controller.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
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
    context.replaceNamed(
      AppRoute.profileForm.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(
      onPressed: onPressed,
      icon: const Icon(Icons.edit),
    );
  }
}
