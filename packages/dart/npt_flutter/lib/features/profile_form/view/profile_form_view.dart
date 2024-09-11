import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_form/profile_form.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_card.dart';

class ProfileFormView extends StatelessWidget {
  final String uuid;
  const ProfileFormView(this.uuid, {super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final GlobalKey<FormState> formkey = GlobalKey<FormState>();
    return BlocProvider<ProfileBloc>(
      create: (BuildContext context) =>

          /// Local copy of the profile which is used by the form
          ProfileBloc(context.read<ProfileRepository>(), uuid)..add(const ProfileLoadOrCreateEvent()),
      child: Padding(
        padding: const EdgeInsets.only(left: Sizes.p100, right: Sizes.p100, top: Sizes.p20),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomCard.profileFormContent(
                    child: SingleChildScrollView(
                      child: Form(
                        key: formkey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ProfileDisplayNameTextField(),
                            gapH10,
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: Sizes.p50),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ProfileDeviceAtSignTextField(),
                                  ProfileDeviceNameTextField(),
                                ],
                              ),
                            ),
                            gapH10,
                            const ProfileRelayQuickButtons(),
                            gapH10,
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: Sizes.p50),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  ProfileLocalPortSelector(),
                                  ProfileRemoteHostTextField(),
                                  ProfileRemotePortSelector(),
                                ],
                              ),
                            ),
                            gapH20,
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: Sizes.p50),
                              child: Builder(
                                builder: (context) => Center(
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        if (!formkey.currentState!.validate()) return;

                                        var localBloc = context.read<ProfileBloc>();
                                        if (localBloc.state is! ProfileLoadedState) return;

                                        /// Now take the localBloc and upload it back to the global bloc
                                        context.read<ProfileCacheCubit>().getProfileBloc(uuid).add(ProfileSaveEvent(
                                              profile: (localBloc.state as ProfileLoadedState).profile,
                                            ));
                                      },
                                      child: Text(strings.submit),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  gapH16,
                  Text(strings.allRightsReserved),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
