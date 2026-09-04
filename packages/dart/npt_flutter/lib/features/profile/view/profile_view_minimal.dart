import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileViewMinimal extends StatelessWidget {
  const ProfileViewMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ProfileSelectBox(),
        gapW10,
        const Expanded(flex: 3, child: ProfileDisplayName()),
        gapW10,
        const Expanded(flex: 3, child: ProfileStatusIndicator()),
        const Spacer(),
        const ProfileFavoriteButton(),
        const ProfilePopupMenuButton(),
      ],
    );
  }
}
