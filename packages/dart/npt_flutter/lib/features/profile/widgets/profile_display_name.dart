import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';

import '../../../styles/sizes.dart';

class ProfileDisplayName extends StatelessWidget {
  const ProfileDisplayName({
    required this.width,
    super.key,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
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
            return Tooltip(message: displayName, child: Text(displayName));
          },
        ),
      ),
    );
  }
}
