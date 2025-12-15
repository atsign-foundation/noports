import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/bloc/profile_list_bloc.dart';
import 'package:npt_flutter/features/settings/bloc/settings_bloc.dart';
import 'package:npt_flutter/styles/sizes.dart';

class PinFavoritesSwitch extends StatelessWidget {
  const PinFavoritesSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<SettingsBloc, SettingsState>(
      // ONLY listen when pinFavorites changes
      listenWhen: (previous, current) {
        return previous is SettingsLoaded &&
            current is SettingsLoaded &&
            previous.settings.pinFavorites != current.settings.pinFavorites;
      },
      // Trigger a sort event AFTER settings have updated
      listener: (context, state) {
        final profileListBloc = context.read<ProfileListBloc>();
        if (profileListBloc.state is! ProfileListLoaded) return;

        profileListBloc.add(
          ProfileListSortEvent(
            sortColumn: (profileListBloc.state as ProfileListLoaded).sortColumn,
            inverseSortOrder: false,
          ),
        );
      },
      child: BlocSelector<SettingsBloc, SettingsState, bool>(
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
                          settings: currentSettings.copyWith(
                            pinFavorites: value,
                          ),
                          save: true,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
