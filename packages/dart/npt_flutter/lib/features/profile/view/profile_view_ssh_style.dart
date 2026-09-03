import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const ProfileSelectBox(),
        gapW10,
        const Expanded(flex: 2, child: ProfileDisplayName()),
        gapW10,
        const Expanded(flex: 2, child: ProfileDeviceName()),
        gapW10,
        const Expanded(flex: 2, child: ProfileServiceView()),
        gapW10,
        const Expanded(flex: 2, child: ProfileStatusIndicator()),
        gapW10,
        const ProfileFavoriteButton(),
        const ProfilePopupMenuButton(),
      ],
    );
  }
}
