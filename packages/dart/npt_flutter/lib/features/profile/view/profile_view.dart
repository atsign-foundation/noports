import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/widgets/profile_delete_button.dart';
import 'package:npt_flutter/features/settings/bloc/settings_bloc.dart';
import 'package:npt_flutter/features/settings/models/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/loader_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(builder: (context, state) {
      if (state is ProfileInitial) {
        context.read<ProfileBloc>().add(const ProfileLoadEvent());
      }
      switch (state) {
        case ProfileInitial _:
        case ProfileLoading _:
          return const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoaderBar(),
              gapW10,
              ProfileRefreshButton(),
            ],
          );

        case ProfileFailedLoad _:
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.p16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.errorProfileLoadFailed),
                const ProfileDeleteButton(),
              ],
            ),
          );

        case ProfileLoadedState _:
          return BlocSelector<SettingsBloc, SettingsState,
              PreferredViewLayout?>(
            selector: (SettingsState state) {
              if (state is SettingsLoadedState) {
                return state.settings.viewLayout;
              }
              return null;
            },
            builder: (BuildContext context, PreferredViewLayout? viewLayout) {
              return switch (viewLayout) {
                null => const Center(child: Spinner()),
                PreferredViewLayout.minimal => const ProfileViewMinimal(),
                PreferredViewLayout.sshStyle => const ProfileViewSshStyle(),
              };
            },
          );
      }
    });
  }
}
