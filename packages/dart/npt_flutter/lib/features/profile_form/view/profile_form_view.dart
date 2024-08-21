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

          /// Local copy of the profile which is used by the form
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
                if (localBloc.state is! ProfileLoadedState) return;

                /// Now take the localBloc and upload it back to the global bloc
                context
                    .read<ProfileCacheCubit>()
                    .getProfileBloc(uuid)
                    .add(ProfileSaveEvent(
                      profile: (localBloc.state as ProfileLoadedState).profile,
                    ));
              },
              child: const Text("Submit"),
            ),
          ),
        ],
      ),
    );
  }
}
