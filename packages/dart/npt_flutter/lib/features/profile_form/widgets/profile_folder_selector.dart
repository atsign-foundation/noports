import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

/// The folder chosen in the form, applied on submit. Null is "No folder".
class ProfileFormFolderCubit extends Cubit<String?> {
  ProfileFormFolderCubit(super.initialState);

  void choose(String? groupId) => emit(groupId);
}

/// Hidden until there is a folder to choose.
class ProfileFolderSelector extends StatelessWidget {
  static const String _noFolder = '';

  const ProfileFolderSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileGroupBloc, ProfileGroupState>(
      builder: (BuildContext context, ProfileGroupState groups) {
        if (groups is! ProfileGroupsLoaded || groups.groups.isEmpty) {
          return gap0;
        }
        final String? chosen = context.watch<ProfileFormFolderCubit>().state;
        final ProfileGroup? folder = groups.data.groupById(chosen ?? '');
        return Padding(
          padding: const EdgeInsets.only(
            left: Sizes.p50,
            right: Sizes.p50,
            top: Sizes.p10,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(strings.profileFolder),
              gapH4,
              Text(
                strings.profileFolderDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              gapH10,
              SizedBox(
                width: double.infinity,
                child: DropdownMenu<String>(
                  // Rebuilt when the folder is renamed or deleted, e.g. by a
                  // sync: the menu only reads its selection once.
                  key: ValueKey<String>(
                    'ProfileFolderSelector-${folder?.uuid}-${folder?.name}',
                  ),
                  initialSelection: folder?.uuid ?? _noFolder,
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: <DropdownMenuEntry<String>>[
                    DropdownMenuEntry<String>(
                      value: _noFolder,
                      label: strings.groupNoFolder,
                    ),
                    for (final ProfileGroup group in groups.groups)
                      DropdownMenuEntry<String>(
                        value: group.uuid,
                        label: group.name,
                      ),
                  ],
                  onSelected: (String? value) {
                    if (value == null) return;
                    context.read<ProfileFormFolderCubit>().choose(
                      value == _noFolder ? null : value,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
