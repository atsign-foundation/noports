import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../styles/sizes.dart';

class ProfileRunButton extends StatelessWidget {
  const ProfileRunButton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: Sizes.p40,
      child: BlocSelector<ProfileBloc, ProfileState, ProfileLoadedState?>(
        selector: (ProfileState state) {
          if (state is ProfileLoadedState) {
            return state;
          }
          return null;
        },
        builder: (BuildContext context, ProfileLoadedState? state) => switch (state) {
          null => gap0,
          ProfileLoaded() || ProfileFailedSave() || ProfileFailedStart() => IconButton(
              icon: PhosphorIcon(PhosphorIcons.play()),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStartEvent());
              },
            ),
          ProfileStarting() => const Spinner(),
          ProfileStarted() => IconButton(
              icon: PhosphorIcon(PhosphorIcons.stop()),
              onPressed: () {
                context.read<ProfileBloc>().add(const ProfileStopEvent());
              },
            ),
          ProfileStopping() => const Spinner(),
        },
      ),
    );
  }
}
