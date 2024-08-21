import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileFormView extends StatelessWidget {
  final String uuid;
  const ProfileFormView(this.uuid, {super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileBloc>(
      create: (BuildContext context) =>

          /// Global copy of the profile which is shared with the rest of the app
          context.read<ProfileCacheCubit>().getProfileBloc(uuid)
            ..add(const ProfileLoadOrCreateEvent()),
      child: BlocSelector<ProfileBloc, ProfileState, bool>(
          selector: (state) => state is ProfileLoadedState,
          builder: (context, isLoaded) {
            if (!isLoaded) return const Spinner();
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
                        var globalBloc = context
                            .read<ProfileCacheCubit>()
                            .getProfileBloc(uuid);

                        if (localBloc.state is ProfileLoadedState &&
                            globalBloc.state is ProfileLoadedState) {
                          globalBloc.add(ProfileEditEvent(
                            profile:
                                (localBloc.state as ProfileLoadedState).profile,
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
          }),
    );
  }
}
