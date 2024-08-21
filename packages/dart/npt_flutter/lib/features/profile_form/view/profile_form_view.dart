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

          /// Don't use [ProfileCacheCubit] here, if we don't hit submit we want
          /// all of the edits to automatically be lost
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
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                var localBloc = context.read<ProfileBloc>();
                var globalBloc =
                    context.read<ProfileCacheCubit>().getProfileBloc(uuid);
                if (localBloc.state is ProfileLoadedState &&
                    globalBloc.state is ProfileLoadedState) {
                  globalBloc.add(ProfileEditEvent(
                    profile: (localBloc.state as ProfileLoadedState).profile,
                    save: true,
                    addToProfilesList: true,
                    popNavAfterAddToProfilesList: true,
                  ));
                }
              },
              child: const Text("Submit"),
            ),
          ),
        ],
      ),
    );
  }
}
