import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/features/profile_form/widgets/profile_local_host_text_field.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_card.dart';

class ProfileFormView extends StatelessWidget {
  final String uuid;
  final Profile? copyFrom;
  final String? groupId;
  const ProfileFormView(
    this.uuid, {
    super.key,
    this.copyFrom,
    this.groupId,
  });

  /// Moves the profile to the folder chosen in the form, if it changed.
  void _applyFolder(BuildContext context) {
    final String? chosen = context.read<ProfileFormFolderCubit>().state;
    final ProfileGroupBloc groupBloc = context.read<ProfileGroupBloc>();
    final ProfileGroupState groups = groupBloc.state;
    if (groups is! ProfileGroupsLoaded) return;
    if (groups.data.groupForProfile(uuid)?.uuid == chosen) return;
    groupBloc.add(
      ProfileGroupMoveProfilesEvent(
        profileIds: [uuid],
        groupId: chosen,
        visibleUngrouped: chosen == null
            ? ProfileGroupActions.visibleUngrouped(context)
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final GlobalKey<FormState> formkey = GlobalKey<FormState>();
    final deviceSize = MediaQuery.of(context).size;
    return MultiBlocProvider(
      providers: [
        BlocProvider<ProfileBloc>(
          create: (BuildContext context) =>
              /// Local copy of the profile which is used by the form
              ProfileBloc(context.read<ProfileRepository>(), uuid)
                ..add(ProfileLoadOrCreateEvent(copyFrom: copyFrom)),
        ),
        BlocProvider<ProfileFormFolderCubit>(
          create: (BuildContext context) {
            final ProfileGroupState groups = context
                .read<ProfileGroupBloc>()
                .state;
            return ProfileFormFolderCubit(
              groupId ??
                  (groups is ProfileGroupsLoaded
                      ? groups.data.groupForProfile(uuid)?.uuid
                      : null),
            );
          },
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(left: Sizes.p100, right: Sizes.p100),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CustomCard.profileFormContent(
                    height: deviceSize.height * Sizes.dashboardCardHeightFactor,
                    child: SingleChildScrollView(
                      child: Form(
                        key: formkey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const ProfileDisplayNameTextField(),
                            const ProfileFolderSelector(),
                            gapH10,
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Sizes.p50,
                              ),
                              child: Row(
                                children: [
                                  ProfileDeviceAtsignTextField(),
                                  gapW143,
                                  ProfileDeviceNameTextField(),
                                ],
                              ),
                            ),
                            gapH10,
                            const ProfileRelayQuickButtons(),
                            gapH10,
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Sizes.p50,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Expanded(child: ProfileLocalPortSelector()),
                                  gapW103,
                                  Expanded(child: ProfileLocalHostTextField()),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: Sizes.p50,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Expanded(child: ProfileRemotePortSelector()),
                                  gapW103,
                                  Expanded(child: ProfileRemoteHostTextField()),
                                ],
                              ),
                            ),
                            // gapH10,
                            const ProfileConnectUriFields(),
                            gapH40,
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sizes.p50,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    strings.advancedSettings,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  gapH10,
                                  const Profile443Checkbox(),
                                  gapH10,
                                  const ProfileKeepAliveCheckbox(),
                                ],
                              ),
                            ),
                            gapH20,
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: Sizes.p50,
                              ),
                              child: Builder(
                                builder: (context) => SizedBox(
                                  width: Sizes.p743,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (!formkey.currentState!.validate())
                                        return;

                                      var localBloc = context
                                          .read<ProfileBloc>();
                                      if (localBloc.state
                                          is! ProfileLoadedState)
                                        return;

                                      /// Now take the localBloc and upload it back to the global bloc
                                      context
                                          .read<ProfileCacheCubit>()
                                          .getProfileBloc(uuid)
                                          .add(
                                            ProfileSaveEvent(
                                              profile:
                                                  (localBloc.state
                                                          as ProfileLoadedState)
                                                      .profile,
                                            ),
                                          );
                                      _applyFolder(context);
                                    },
                                    child: Text(strings.submit),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
