import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/settings/bloc/settings_bloc.dart';
import 'package:npt_flutter/styles/sizes.dart';

class PinFavoritesSwitch extends StatelessWidget {
  const PinFavoritesSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsBloc, SettingsState, bool>(
      selector: (state) {
        if (state is SettingsLoaded) {
          return state.settings.pinFavorites;
        }
        return true;
      },
      builder: (context, isPinned) {
        return Row(
          children: [
            const Text('Pin Favorites'),
            gapW10,
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: isPinned,
                onChanged: (value) {
                  final settingsBloc = context.read<SettingsBloc>();
                  if (settingsBloc.state is SettingsLoaded) {
                    final currentSettings =
                        (settingsBloc.state as SettingsLoaded).settings;

                    settingsBloc.add(
                      SettingsEditEvent(
                        settings: currentSettings.copyWith(pinFavorites: value),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
