import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      ProfileSelectBox(),
      ProfileDisplayName(),
      ProfileStatusIndicator(),
      ProfileRunButton(),
      ProfilePopupMenuButton(),
    ]);
  }
}
