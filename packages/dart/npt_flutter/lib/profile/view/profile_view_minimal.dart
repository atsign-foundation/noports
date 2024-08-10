import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/profile/profile.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileViewMinimal extends StatelessWidget {
  const ProfileViewMinimal({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (BuildContext context, state) {
        if (state is ProfileInitial) {
          context.read<ProfileBloc>().add(const ProfileLoadEvent());
        }

        return switch (state) {
          ProfileInitial() || ProfileLoading() => const Spinner(),
          ProfileFailedLoad() => const Text("Oh no! something we wrong!"),
          // Note that all the below cases are subclasses of ProfileLoadedState
          ProfileLoaded() ||
          ProfileFailedSave() ||
          ProfileStarting() ||
          ProfileStarted() ||
          ProfileStopping() ||
          ProfileFailedStart() =>
            buildLoaded(context, state as ProfileLoadedState),
        };
      },
    );
  }

  Widget buildLoaded(BuildContext context, ProfileLoadedState state) {
    return Row(
      children: [
        Text(state.profile.displayName),
        switch (state) {
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
        // Status messages
        if (state is ProfileFailedSave)
          const Text("There was an error saving this profile"),
        if (state is ProfileFailedStart)
          Text(
              "Failed to start profile: ${state.reason ?? '<no reason provided>'}"),
        if (state is ProfileStarting && state.status != null)
          Text(state.status!),
      ],
    );
  }
}
