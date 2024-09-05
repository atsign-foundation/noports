import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';

class ProfileViewMinimal extends StatelessWidget {
  const ProfileViewMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      ProfileSelectBox(),
      ProfileStatusIndicator(),
      ProfileDisplayName(),
      ProfileRunButton(),
      ProfileFavoriteButton(),
      ProfilePopupMenuButton(),
    ]);
  }
}
