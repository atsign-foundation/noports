import 'package:flutter/material.dart';
import 'package:noports_core/sshnp.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_actions.dart';

class ProfileBarActions extends StatelessWidget {
  final SshnpParams params;
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
