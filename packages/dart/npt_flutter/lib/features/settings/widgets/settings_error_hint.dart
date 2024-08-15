import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/settings.dart';

class SettingsErrorHint extends StatelessWidget {
  const SettingsErrorHint({
    super.key,
  });

  // A widget which only renders when the settings failed to load
  // Note that the settings screen still gets drawn, as it uses some default values
  // We could/should:
  // - Warn the user that changing any settings will cause the old ones to permanently be lost
  //   - Although we shouldn't scare them, there aren't very many settings
  // - Provide a retry / refresh button
  // - Provide a dimiss / save button which saves the current settings as they are (also wiping the old settings)
  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, bool>(selector: (state) {
      return state is SettingsFailedLoad;
    }, builder: (context, hasError) {
      if (hasError) return const Text("Error loading profile");
      return Container();
    });
  }
}
