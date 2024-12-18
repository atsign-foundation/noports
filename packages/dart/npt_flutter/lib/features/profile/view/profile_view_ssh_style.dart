import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(children: [
      ProfileSelectBox(),
      gapW10,
      ProfileDisplayName(),
      gapW10,
      ProfileDeviceName(),
      gapW10,
      ProfileServiceView(),
      gapW10,
      ProfileStatusIndicator(),
      gapW10,
      ProfileRunButton(),
      gapW10,
      ProfileFavoriteButton(),
      gapW10,
      ProfilePopupMenuButton(),
      gapW20,
    ]);
  }
}
