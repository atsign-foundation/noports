import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints constraints) {
      final width = SizeConfig.setProfileFieldWidth();
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const ProfileSelectBox(),
        gapW10,
        ProfileDisplayName(width: width),
        gapW10,
        ProfileDeviceName(width: width),
        gapW10,
        ProfileServiceView(width: width),
        gapW10,
        ProfileStatusIndicator(width: SizeConfig.setProfileFieldWidth(statusField: true)),
        gapW10,
        const Flexible(child: ProfileRunButton()),
        gapW10,
        const Flexible(child: ProfileFavoriteButton()),
        gapW10,
        const Flexible(child: ProfilePopupMenuButton()),
        gapW10
      ]);
    });
  }
}
