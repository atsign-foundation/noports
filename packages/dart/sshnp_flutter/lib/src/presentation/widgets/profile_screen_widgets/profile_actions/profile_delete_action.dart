import 'package:flutter/material.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_button.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_actions/profile_action_callbacks.dart';

class ProfileDeleteAction extends StatelessWidget {
  final String profileName;
  final bool menuItem;
  const ProfileDeleteAction(this.profileName, {this.menuItem = false, Key? key})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(
      onPressed: () => ProfileActionCallbacks.delete(context, profileName),
      icon: const Icon(Icons.delete_forever),
    );
  }
}
