import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/bloc/profile_group_bloc.dart';
import 'package:npt_flutter/features/profile_group/util/profile_group_actions.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_selected_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Retry button shown only when folders failed to load.
class ProfileGroupLoadRetryButton extends StatelessWidget {
  const ProfileGroupLoadRetryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileGroupBloc, ProfileGroupState>(
      builder: (BuildContext context, ProfileGroupState state) {
        if (state is! ProfileGroupsFailedLoad) return gap0;
        return TextButton.icon(
          onPressed: () {
            context.read<ProfileGroupBloc>().add(const ProfileGroupLoadEvent());
          },
          icon: PhosphorIcon(PhosphorIcons.arrowClockwise()),
          label: Text(strings.groupLoadFailedRetry),
        );
      },
    );
  }
}

/// Creates an empty folder. Hidden while profiles are selected.
class ProfileGroupCreateButton extends StatelessWidget {
  const ProfileGroupCreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, bool>(
      selector: (ProfilesSelectedState state) => state.selected.isNotEmpty,
      builder: (BuildContext context, bool anySelected) {
        if (anySelected) return gap0;
        return BlocSelector<ProfileGroupBloc, ProfileGroupState, bool>(
          selector: (ProfileGroupState state) => state is ProfileGroupsLoaded,
          builder: (BuildContext context, bool foldersEnabled) {
            if (!foldersEnabled) return gap0;
            return ElevatedButton.icon(
              key: const Key('ProfileGroupCreateButton'),
              onPressed: () => ProfileGroupActions.createFolder(context),
              label: Text(strings.groupNewFolder),
              icon: PhosphorIcon(PhosphorIcons.folderPlus()),
            );
          },
        );
      },
    );
  }
}

/// Moves the selected profiles into a folder. Shown only while profiles are
/// selected and folders have loaded.
class ProfileGroupMoveButton extends StatelessWidget {
  const ProfileGroupMoveButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocSelector<
      ProfilesSelectedCubit,
      ProfilesSelectedState,
      Set<String>
    >(
      selector: (ProfilesSelectedState state) => state.selected,
      builder: (BuildContext context, Set<String> selected) {
        if (selected.isEmpty) return gap0;
        return BlocSelector<ProfileGroupBloc, ProfileGroupState, bool>(
          selector: (ProfileGroupState state) => state is ProfileGroupsLoaded,
          builder: (BuildContext context, bool foldersEnabled) {
            if (!foldersEnabled) return gap0;
            return ElevatedButton.icon(
              key: const Key('ProfileGroupMoveButton'),
              onPressed: () async {
                final ProfilesSelectedCubit selectedCubit = context
                    .read<ProfilesSelectedCubit>();
                await ProfileGroupActions.moveToFolder(context, selected);
                selectedCubit.deselectAll();
              },
              label: Text(strings.groupMoveTo),
              icon: PhosphorIcon(PhosphorIcons.folderOpen()),
            );
          },
        );
      },
    );
  }
}
