import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileRunButton extends StatelessWidget {
  const ProfileRunButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileBloc, ProfileState, ProfileLoadedState?>(
      selector: (ProfileState state) {
        if (state is ProfileLoadedState) {
          return state;
        }
        return null;
      },
      builder: (BuildContext context, ProfileLoadedState? state) =>
          switch (state) {
        null => const SizedBox(),
        ProfileLoaded() ||
        ProfileFailedSave() ||
        ProfileFailedStart() =>
          ElevatedButton(
            onPressed: () {
              context.read<ProfileBloc>().add(const ProfileStartEvent());
            },
            child: const Text("Run"),
          ),
        ProfileStarting() => const ElevatedButton(
            onPressed: null,
            child: Row(children: [Text("Starting"), Spinner()]),
          ),
        ProfileStarted() => ElevatedButton(
            onPressed: () {
              context.read<ProfileBloc>().add(const ProfileStopEvent());
            },
            child: const Text("Stop"),
          ),
        ProfileStopping() => const ElevatedButton(
            onPressed: null,
            child: Row(children: [Text("Stopping"), Spinner()]),
          ),
      },
    );
  }
}
