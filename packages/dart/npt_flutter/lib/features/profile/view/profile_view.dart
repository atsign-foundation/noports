import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/settings/settings.dart';
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
              ProfileRefreshButton(),
            ],
          );

        case ProfileFailedLoad _:
          return const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Failed to load this profile, please refresh manually:"),
              ProfileRefreshButton(),
            ],
          );

        case ProfileLoadedState _:
          return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
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
