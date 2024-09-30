import 'package:flutter/material.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileHeaderColumn extends StatelessWidget {
  const ProfileHeaderColumn({super.key, required this.title, this.layout = PreferredViewLayout.sshStyle});

  final String title;
  final PreferredViewLayout layout;

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final double widthFactor =
        layout == PreferredViewLayout.sshStyle ? Sizes.profileFieldsWidthFactor : Sizes.profileFieldsWidthFactorAlt;

    return SizedBox(width: deviceWidth * widthFactor, child: Text(title));
  }
}
