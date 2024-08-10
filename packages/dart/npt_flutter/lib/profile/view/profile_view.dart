import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/profile/profile.dart';
import 'package:npt_flutter/settings/settings.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, PreferredViewLayout?>(
      selector: (SettingsState state) {
        if (state is SettingsLoadedState) {
          return state.settings.viewLayout;
        }
        return null;
      },
      builder: (BuildContext context, PreferredViewLayout? state) {
        return switch (state) {
          null => const Spinner(),
          PreferredViewLayout.minimal => const ProfileViewMinimal(),
          PreferredViewLayout.sshStyle => const ProfileViewSshStyle(),
        };
      },
    );
  }
}
