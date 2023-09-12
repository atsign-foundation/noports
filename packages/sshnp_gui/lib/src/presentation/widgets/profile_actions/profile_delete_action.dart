import 'package:flutter/material.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_action_callbacks.dart';
import 'package:sshnp_gui/src/presentation/widgets/profile_actions/profile_widgets.dart';

class ProfileDeleteAction extends StatelessWidget {
  final String profileName;
  final bool menuItem;
  const ProfileDeleteAction(this.profileName, {this.menuItem = false, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ProfileActionButton(
      onPressed: () => ProfileActionCallbacks.delete(context, profileName),
      icon: const Icon(Icons.delete_forever),
    );
  }
}
