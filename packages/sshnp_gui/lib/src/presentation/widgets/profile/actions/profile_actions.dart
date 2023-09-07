import 'package:flutter/material.dart';
import 'package:sshnoports/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_delete_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_edit_action.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile/actions/profile_run_action.dart';

class ProfileActions extends StatelessWidget {
  final SSHNPParams params;
  const ProfileActions(this.params, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileRunAction(params),
        ProfileEditAction(params),
        ProfileDeleteAction(params),
      ],
    );
  }
}
