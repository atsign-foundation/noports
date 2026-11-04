import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_folder/profile_folder.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ProfileSelectAllBox extends StatelessWidget {
  const ProfileSelectAllBox({super.key});

  @override
  Widget build(BuildContext context) {
    final ProfileListFilterState filter = context
        .watch<ProfileListFilterCubit>()
        .state;
    final ProfileFolderState folders = context.watch<ProfileFolderBloc>().state;
    // Rows a search or a collapsed folder hides aren't selected.
    bool shownRow(String uuid) =>
        filter.matches(uuid) &&
        (filter.searching ||
            folders is! ProfileFoldersLoaded ||
            !folders.data.isCollapsed(uuid));
    return BlocBuilder<ProfileListBloc, ProfileListState>(
      builder: (BuildContext context, ProfileListState list) {
        final List<String>? shown = list is ProfileListLoaded
            ? list.profiles.where(shownRow).toList()
            : null;
        return BlocSelector<
          ProfilesSelectedCubit,
          ProfilesSelectedState,
          (bool, bool)?
        >(
          selector: (ProfilesSelectedState state) {
            if (shown == null) return null;
            // one - whether all elements are selected or not
            var allChecked =
                shown.isNotEmpty && state.selected.containsAll(shown);
            // two - whether some elements are selected or not
            var anyChecked = state.selected.isNotEmpty;
            return (allChecked, anyChecked);
          },
          builder: (BuildContext context, (bool, bool)? tuple) {
            if (tuple == null) return gap0;
            var (allChecked, someChecked) = tuple;
            return Checkbox(
              tristate: true,
              value: allChecked
                  ? true // if all Checked show checkmark
                  : someChecked
                  ? null // if some checked show [-]
                  : false, // if none checked show empty box
              onChanged: (bool? value) {
                // This seems unintuitive, but tristate: true makes the checkbox act a bit strange
                // How this behaves:
                // - All checked - deselectAll
                // - Some or none checked - selectAll
                switch (value) {
                  case null: // All checked transitions to null with tristate: true
                    context.read<ProfilesSelectedCubit>().deselectAll();
                  case true: // None checked transitions to true with tristate: true
                  case false: // Some checked transitions to false with tristate: true
                    context.read<ProfilesSelectedCubit>().selectOnly(shown!);
                }
              },
            );
          },
        );
      },
    );
  }
}
