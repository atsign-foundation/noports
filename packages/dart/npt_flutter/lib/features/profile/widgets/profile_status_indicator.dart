import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileStatusIndicator extends StatelessWidget {
  const ProfileStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Sizes.p150,
      child: BlocBuilder<ProfileBloc, ProfileState>(builder: (BuildContext context, ProfileState state) {
        if (state is ProfileFailedSave) {
          return const Tooltip(message: 'error saving profile', child: Text("Failed"));
        }

        if (state is ProfileFailedStart) {
          return Tooltip(message: state.reason ?? 'No Reason Provided', child: const Text("Failed"));
        }

        if (state is ProfileStarting && state.status != null) {
          return Text(state.status!);
        }

        return gap0;
      }),
    );
  }
}
