import 'package:flutter/material.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

class ProfileViewSshStyle extends StatelessWidget {
  const ProfileViewSshStyle({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileColumnsRow(
      layout: PreferredViewLayout.sshStyle,
      select: const ProfileSelectBox(),
      cellBuilder: (ProfileColumn column, double width) =>
          ProfileColumnCell(column: column, width: width),
      favorite: const ProfileFavoriteButton(),
      menu: const ProfilePopupMenuButton(),
    );
  }
}
