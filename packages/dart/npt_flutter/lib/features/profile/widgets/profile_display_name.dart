import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';

import '../../../styles/sizes.dart';

class ProfileDisplayName extends StatelessWidget {
  const ProfileDisplayName({super.key, this.layout = PreferredViewLayout.sshStyle});

  final PreferredViewLayout layout;

  @override
  Widget build(BuildContext context) {
    final deviceWidth = MediaQuery.of(context).size.width;
    final double widthFactor =
        layout == PreferredViewLayout.sshStyle ? Sizes.profileFieldsWidthFactor : Sizes.profileFieldsWidthFactorAlt;
    return SizedBox(
      width: deviceWidth * widthFactor,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: BlocSelector<ProfileBloc, ProfileState, String?>(
          selector: (ProfileState state) {
            if (state is ProfileLoadedState) {
              return state.profile.displayName;
            }
            return null;
          },
          builder: (BuildContext context, String? displayName) {
            if (displayName == null) return gap0;
            return Text(displayName);
          },
        ),
      ),
    );
  }
}
