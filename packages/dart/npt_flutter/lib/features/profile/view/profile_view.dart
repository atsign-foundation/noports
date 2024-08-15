import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
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
          return const Spinner();
        case ProfileFailedLoad _:
          return const Row(
            children: [
              ProfileListRefreshButton(),
              Text("Oh no! something went wrong!"),
            ],
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
                null => const Spinner(),
                PreferredViewLayout.minimal => const ProfileViewMinimal(),
                PreferredViewLayout.sshStyle => const ProfileViewSshStyle(),
              };
            },
          );
      }
    });
  }
}
