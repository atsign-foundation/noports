import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileStatusIndicator extends StatelessWidget {
  const ProfileStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(builder: (BuildContext context, ProfileState state) {
      if (state is ProfileFailedSave) {
        return const Text("There was an error saving this profile");
      }

      if (state is ProfileFailedStart) {
        return Text("Failed to start profile: ${state.reason ?? '<no reason provided>'}");
      }

      if (state is ProfileStarting && state.status != null) {
        return Text(state.status!);
      }

      return gapW38;
    });
  }
}
