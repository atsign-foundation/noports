import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileViewMinimal extends StatelessWidget {
  const ProfileViewMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      ProfileSelectBox(),
      gapW10,
      ProfileDisplayName(),
      gapW10,
      ProfileStatusIndicator(),
      gapW10,
      Spacer(),
      ProfileRunButton(),
      gapW10,
      ProfileFavoriteButton(),
      gapW10,
      ProfilePopupMenuButton(),
      gapW20,
    ]);
  }
}
