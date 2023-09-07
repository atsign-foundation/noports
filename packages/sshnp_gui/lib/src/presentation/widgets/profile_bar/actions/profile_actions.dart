import 'package:flutter/material.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/actions/profile_delete_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/actions/profile_edit_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/actions/profile_run_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_bar/actions/profile_terminal_action.dart';

class ProfileActions extends StatelessWidget {
  final SSHNPParams params;
  const ProfileActions(this.params, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileRunAction(params),
        ProfileTerminalAction(params),
        ProfileEditAction(params),
        ProfileDeleteAction(params),
      ],
    );
  }
}
