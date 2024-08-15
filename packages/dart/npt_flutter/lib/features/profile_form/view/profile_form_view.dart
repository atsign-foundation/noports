import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';

class ProfileFormView extends StatelessWidget {
  final String uuid;
  const ProfileFormView(this.uuid, {super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (BuildContext context) =>
          ProfileBloc(context.read<ProfileRepository>(), uuid)
            ..add(const ProfileLoadOrCreateEvent()),
      child: Column(
        children: [
          const ProfileDisplayNameTextField(),
          const ProfileDeviceAtSignTextField(),
          const ProfileDeviceNameTextField(),
          const ProfileRelayAtSignTextField(),
          const ProfileRelayQuickButtons(),
          const ProfileRemoteHostTextField(),
          const ProfileRemotePortSelector(),
          const ProfileLocalPortSelector(),
          ElevatedButton(
            onPressed: () {
              var bloc = context.read<ProfileBloc>();
              if (bloc.state is ProfileLoadedState) {
                bloc.add(ProfileEditEvent(
                  profile: (bloc.state as ProfileLoadedState).profile,
                  save: true,
                  addToProfilesList: true,
                  popNavAfterAddToProfilesList: true,
                ));
              }
            },
            child: const Text("Submit"),
          ),
        ],
      ),
    );
  }
}
