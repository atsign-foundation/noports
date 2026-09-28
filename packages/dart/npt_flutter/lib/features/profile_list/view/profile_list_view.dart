import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:npt_flutter/features/back_up_key/util/backup_key_utils.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile/view/profile_header_view.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/features/profile_list/cubit/sync_cubit.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/features/profile_list/widgets/demo_profile_info_widget.dart';
import 'package:npt_flutter/features/profile_list/widgets/profile_list_failed_load_content.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/widgets/custom_snack_bar.dart';
import 'package:npt_flutter/widgets/spinner.dart';

class ProfileListView extends StatefulWidget {
  const ProfileListView({super.key});

  @override
  State<ProfileListView> createState() => _ProfileListViewState();
}

class _ProfileListViewState extends State<ProfileListView> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await BackupKeyUtils().backupKeyStatusCheck();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final bodyMedium = Theme.of(context).textTheme.bodyMedium;
    SizeConfig().init();

    return BlocProvider<ProfileListFilterCubit>(
      create: (BuildContext context) {
        final ProfileListFilterCubit filter = ProfileListFilterCubit(
          context.read<ProfileCacheCubit>(),
        );
        final SettingsState settings = context.read<SettingsBloc>().state;
        if (_isUserSettings(settings)) {
          filter.useSettings((settings as SettingsLoadedState).settings);
        }
        final ProfileListState list = context.read<ProfileListBloc>().state;
        if (list is ProfileListLoaded) filter.setProfiles(list.profiles);
        final ProfileGroupState folders = context
            .read<ProfileGroupBloc>()
            .state;
        if (folders is ProfileGroupsLoaded) filter.setFolders(folders.groups);
        return filter;
      },
      child: MultiBlocListener(
        listeners: [
          BlocListener<SyncCubit, bool>(
            listenWhen: (previous, current) => previous != current,
            listener: (context, isInSync) {
              if (isInSync == false) {
                CustomSnackBar.notification(content: strings.syncInProgress);
              } else {
                CustomSnackBar.notification(content: strings.syncCompleted);
              }
            },
          ),
          BlocListener<SettingsBloc, SettingsState>(
            listener: (BuildContext context, SettingsState state) {
              if (_isUserSettings(state)) {
                context.read<ProfileListFilterCubit>().useSettings(
                  (state as SettingsLoadedState).settings,
                );
              }
            },
          ),
          // Selected connections the search hides would still be exported,
          // moved or deleted.
          BlocListener<ProfileListFilterCubit, ProfileListFilterState>(
            listener: (BuildContext context, ProfileListFilterState filter) {
              final ProfilesSelectedCubit selected = context
                  .read<ProfilesSelectedCubit>();
              if (selected.state.selected.any(filter.hides)) {
                selected.retain(
                  selected.state.selected.where((id) => !filter.hides(id)),
                );
              }
            },
          ),
          BlocListener<ProfileGroupBloc, ProfileGroupState>(
            listener: (BuildContext context, ProfileGroupState state) {
              context.read<ProfileListFilterCubit>().setFolders(
                state is ProfileGroupsLoaded
                    ? state.groups
                    : const <ProfileGroup>[],
              );
            },
          ),
          BlocListener<ProfileListBloc, ProfileListState>(
            listener: (BuildContext context, ProfileListState state) {
              if (state is ProfileListLoaded) {
                context.read<ProfileListFilterCubit>().setProfiles(
                  state.profiles,
                );
              }
            },
          ),
        ],
        child: BlocBuilder<ProfileListBloc, ProfileListState>(
          builder: (context, state) {
            return switch (state) {
              ProfileListInitial() ||
              ProfileListLoading() => const Center(child: Spinner()),
              ProfileListFailedLoad() => const ProfileListFailedLoadContent(),
              ProfileListLoaded() =>
                BlocBuilder<ProfileListBloc, ProfileListState>(
                  builder: (BuildContext context, ProfileListState state) {
                    if (state is! ProfileListLoaded) {
                      return gap0;
                    }

                    final profiles = state.profiles.toList();
                    final isFullProfile = profiles.isNotEmpty;
                    log('profile: isFullProfile: $isFullProfile');

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.p20,
                        vertical: Sizes.p10,
                      ),
                      child: Column(
                        children: [
                          isFullProfile
                              ? const Row(
                                  children: [
                                    // Takes the free space, so the buttons
                                    // stay right and the search only shrinks
                                    // when space runs out.
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            flex: 2,
                                            child: ProfileListSearchField(),
                                          ),
                                          gapW4,
                                          ProfileListSortButton(),
                                          gapW10,
                                          Flexible(
                                            child:
                                                ProfileGroupLoadRetryButton(),
                                          ),
                                        ],
                                      ),
                                    ),
                                    gapW10,
                                    ProfileListAddButton(),
                                    gapW10,
                                    ProfileGroupCreateButton(),
                                    gapW10,
                                    ProfileListImportButton(),
                                    gapW10,
                                    ProfileGroupMoveButton(),
                                    gapW10,
                                    ProfileSelectedExportButton(),
                                    gapW10,
                                    ProfileSelectedDeleteButton(),
                                  ],
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    ProfileListAddButton(),
                                    gapW10,
                                    ProfileListImportButton(),
                                  ],
                                ),
                          gapH8,
                          if (isFullProfile) const ProfileHeaderView(),
                          if (isFullProfile)
                            Expanded(child: _FilteredList(profiles: profiles)),
                          if (!isFullProfile)
                            Expanded(
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SvgPicture.asset(
                                      'assets/empty_state_profile_bg.svg',
                                      height: Sizes.p200,
                                    ),
                                    gapH16,
                                    const DemoProfileInfoWidget(),
                                    gapH16,
                                    Text(
                                      strings.emptyProfileMessage,
                                      style: bodyMedium?.copyWith(
                                        fontSize: Sizes.p16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
            };
          },
        ),
      ),
    );
  }
}

/// Settings the user saved, as opposed to the defaults a failed load falls
/// back to.
bool _isUserSettings(SettingsState state) =>
    state is SettingsLoadedState && state is! SettingsFailedLoad;

class _FilteredList extends StatelessWidget {
  final List<String> profiles;
  const _FilteredList({required this.profiles});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileListFilterCubit, ProfileListFilterState>(
      builder: (BuildContext context, ProfileListFilterState filter) {
        return BlocSelector<FavoriteBloc, FavoritesState, Set<String>>(
          selector: (FavoritesState state) =>
              state is FavoritesLoaded ? state.profileUuids : const <String>{},
          builder: (BuildContext context, Set<String> favorites) {
            final bool noResults =
                filter.searching &&
                !filter.anyFolderMatches &&
                profiles.every(filter.settled) &&
                !profiles.any(filter.matches);
            // Kept mounted under the message so folders stay collapsed.
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Offstage(
                  offstage: noResults,
                  child: ProfileGroupedListView(
                    profiles: profiles,
                    arrange: filter.isDefault
                        ? null
                        : (List<String> uuids) =>
                              filter.apply(uuids, favorites),
                    searching: filter.searching,
                    folderMatches: filter.folderMatches,
                    compareFolders: filter.folderOrder,
                    reorderable: filter.manualOrder,
                    movable: !filter.searching,
                  ),
                ),
                if (noResults)
                  Center(child: Text(strings.profileSearchNoResults)),
              ],
            );
          },
        );
      },
    );
  }
}
