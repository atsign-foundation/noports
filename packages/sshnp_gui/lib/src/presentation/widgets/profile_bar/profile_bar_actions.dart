import 'package:flutter/material.dart';
import 'package:noports_core/sshnp/sshnp.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_actions.dart';

class ProfileBarActions extends StatelessWidget {
  final SSHNPParams params;
  const ProfileBarActions(this.params, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ProfileRunAction(params),
        ProfileTerminalAction(params),
        ProfileMenuButton(params.profileName!),
      ],
    );
  }
}
