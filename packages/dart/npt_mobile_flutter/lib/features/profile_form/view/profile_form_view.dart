import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/profile/profile.dart';
import 'package:npt_mobile_flutter/features/profile_form/profile_form.dart';
import 'package:npt_mobile_flutter/features/profile_form/widgets/profile_local_host_text_field.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

class ProfileFormView extends StatelessWidget {
  final String uuid;
  final Profile? copyFrom;
  const ProfileFormView(this.uuid, {super.key, this.copyFrom});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final GlobalKey<FormState> formkey = GlobalKey<FormState>();
    return BlocProvider<ProfileBloc>(
      create: (BuildContext context) =>
          /// Local copy of the profile which is used by the form
          ProfileBloc(context.read<ProfileRepository>(), uuid)
            ..add(ProfileLoadOrCreateEvent(copyFrom: copyFrom)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formkey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ProfileDisplayNameTextField(),
              gapH10,
              const ProfileDeviceAtSignTextField(),
              gapH10,
              const ProfileDeviceNameTextField(),
              gapH10,
              const ProfileRelayQuickButtons(),
              gapH10,
              const ProfileLocalPortSelector(),
              gapH10,
              const ProfileLocalHostTextField(),
              gapH10,
              const ProfileRemotePortSelector(),
              gapH10,
              const ProfileRemoteHostTextField(),
              gapH10,
              const ProfileConnectUriFields(),
              gapH20,
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
              gapH20,
              Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    if (!formkey.currentState!.validate()) return;

                    var localBloc = context.read<ProfileBloc>();
                    if (localBloc.state is! ProfileLoadedState) return;

                    /// Now take the localBloc and upload it back to the global bloc
                    context
                        .read<ProfileCacheCubit>()
                        .getProfileBloc(uuid)
                        .add(
                          ProfileSaveEvent(
                            profile:
                                (localBloc.state as ProfileLoadedState).profile,
                          ),
                        );
                  },
                  child: Text(strings.submit),
                ),
              ),
              const SizedBox(height: 40), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }
}
