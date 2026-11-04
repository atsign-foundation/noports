import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_folder/bloc/profile_folder_bloc.dart';
import 'package:npt_flutter/features/profile_folder/util/profile_folder_actions.dart';
import 'package:npt_flutter/features/profile_list/cubit/profiles_selected_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Shown only when folders failed to load. Flexible, so it must sit in a Row.
class ProfileFolderLoadRetryButton extends StatelessWidget {
  const ProfileFolderLoadRetryButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileFolderBloc, ProfileFolderState>(
      builder: (BuildContext context, ProfileFolderState state) {
        if (state is! ProfileFoldersFailedLoad) return gap0;
        return Flexible(
          child: TextButton.icon(
            onPressed: () {
              context.read<ProfileFolderBloc>().add(
                const ProfileFolderLoadEvent(),
              );
            },
            icon: PhosphorIcon(PhosphorIcons.arrowClockwise()),
            label: Text(
              strings.folderLoadFailedRetry,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      },
    );
  }
}

/// Creates an empty folder. Hidden while profiles are selected.
class ProfileFolderCreateButton extends StatelessWidget {
  const ProfileFolderCreateButton({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, bool>(
      selector: (ProfilesSelectedState state) => state.selected.isNotEmpty,
      builder: (BuildContext context, bool anySelected) {
        if (anySelected) return gap0;
        return BlocSelector<ProfileFolderBloc, ProfileFolderState, bool>(
          selector: (ProfileFolderState state) => state is ProfileFoldersLoaded,
          builder: (BuildContext context, bool foldersEnabled) {
            if (!foldersEnabled) return gap0;
            return ElevatedButton.icon(
              key: const Key('ProfileFolderCreateButton'),
              onPressed: () => ProfileFolderActions.createFolder(context),
              label: Text(strings.folderNew),
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
class ProfileFolderMoveButton extends StatelessWidget {
  const ProfileFolderMoveButton({super.key});

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
        return BlocSelector<ProfileFolderBloc, ProfileFolderState, bool>(
          selector: (ProfileFolderState state) => state is ProfileFoldersLoaded,
          builder: (BuildContext context, bool foldersEnabled) {
            if (!foldersEnabled) return gap0;
            return ElevatedButton.icon(
              key: const Key('ProfileFolderMoveButton'),
              onPressed: () async {
                final ProfilesSelectedCubit selectedCubit = context
                    .read<ProfilesSelectedCubit>();
                if (await ProfileFolderActions.moveToFolder(
                  context,
                  selected,
                )) {
                  selectedCubit.deselectAll();
                }
              },
              label: Text(strings.folderMoveTo),
              icon: PhosphorIcon(PhosphorIcons.folderOpen()),
            );
          },
        );
      },
    );
  }
}
