import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileListSortButton extends StatelessWidget {
  const ProfileListSortButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileListFilterCubit, ProfileListFilterState>(
      buildWhen: (ProfileListFilterState a, ProfileListFilterState b) =>
          a.sortMode != b.sortMode || a.favoritesFirst != b.favoritesFirst,
      builder: (BuildContext context, ProfileListFilterState filter) {
        return PopupMenuButton<Object>(
          key: const Key('ProfileListSortButton'),
          tooltip: strings.profileSortTooltip,
          icon: PhosphorIcon(
            PhosphorIcons.sortAscending(),
            color: filter.reordered ? AppColor.primaryColor : null,
          ),
          onSelected: (Object value) {
            switch (value) {
              case ProfileSortMode sortMode:
                _save(context, sortMode: sortMode);
              case bool favoritesFirst:
                _save(context, favoritesFirst: favoritesFirst);
            }
          },
          itemBuilder: (BuildContext _) => <PopupMenuEntry<Object>>[
            for (final ProfileSortMode mode in ProfileSortMode.values)
              CheckedPopupMenuItem<Object>(
                value: mode,
                checked: filter.sortMode == mode,
                child: Text(switch (mode) {
                  ProfileSortMode.manual => strings.profileSortManual,
                  ProfileSortMode.nameAscending =>
                    strings.profileSortNameAscending,
                  ProfileSortMode.nameDescending =>
                    strings.profileSortNameDescending,
                }),
              ),
            const PopupMenuDivider(),
            CheckedPopupMenuItem<Object>(
              value: !filter.favoritesFirst,
              checked: filter.favoritesFirst,
              child: Text(strings.profileSortFavoritesFirst),
            ),
          ],
        );
      },
    );
  }

  void _save(
    BuildContext context, {
    ProfileSortMode? sortMode,
    bool? favoritesFirst,
  }) {
    final ProfileListFilterCubit filter = context
        .read<ProfileListFilterCubit>();
    if (sortMode != null) filter.sort(sortMode);
    if (favoritesFirst != null) filter.setFavoritesFirst(favoritesFirst);

    // Saving over settings that failed to load would replace them with defaults.
    final SettingsBloc settingsBloc = context.read<SettingsBloc>();
    final SettingsState state = settingsBloc.state;
    if (state is! SettingsLoadedState || state is SettingsFailedLoad) return;
    settingsBloc.add(
      SettingsEditEvent(
        settings: state.settings.copyWith(
          // copyWith resets the relay unless it is passed.
          relayAtsign: state.settings.relayAtsign,
          sortMode: sortMode,
          favoritesFirst: favoritesFirst,
        ),
        save: true,
      ),
    );
  }
}
