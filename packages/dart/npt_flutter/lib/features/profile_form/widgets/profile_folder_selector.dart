import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile_group/profile_group.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// A null [groupId] is "No folder". A [newName] is created on submit.
typedef ProfileFormFolder = ({String? groupId, String? newName});

class ProfileFormFolderCubit extends Cubit<ProfileFormFolder> {
  ProfileFormFolderCubit(String? groupId)
    : super((groupId: groupId, newName: null));

  void choose(String? groupId) => emit((groupId: groupId, newName: null));

  void create(String name) => emit((groupId: null, newName: name));
}

class ProfileFolderSelector extends StatefulWidget {
  const ProfileFolderSelector({super.key});

  @override
  State<ProfileFolderSelector> createState() => _ProfileFolderSelectorState();
}

class _ProfileFolderSelectorState extends State<ProfileFolderSelector> {
  static const String _noFolder = '';
  static const String _newFolder = ':new';
  static const String _createFolder = ':create';
  static const String _createNamed = ':create:';

  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();

  /// Bumped to show the chosen folder again, e.g. after typing without
  /// picking anything.
  int _resets = 0;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        // Typing replaces the chosen folder's name rather than adding to it.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_focus.hasFocus) return;
          _text.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _text.text.length,
          );
        });
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_focus.hasFocus) setState(() => _resets++);
      });
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    final ProfileFormFolderCubit cubit = context.read<ProfileFormFolderCubit>();
    final String? name = await showDialog<String>(
      context: context,
      builder: (BuildContext _) =>
          ProfileGroupNameDialog(title: strings.groupNewFolder),
    );
    if (name != null && name.isNotEmpty) {
      cubit.create(name);
    } else if (mounted) {
      setState(() => _resets++);
    }
  }

  /// Typing a name no folder has offers to create it.
  List<DropdownMenuEntry<String>> _filter(
    List<DropdownMenuEntry<String>> entries,
    String filter,
  ) {
    final String typed = filter.trim().toLowerCase();
    final List<DropdownMenuEntry<String>> matches = entries
        .where(
          (DropdownMenuEntry<String> e) =>
              e.label.toLowerCase().contains(typed),
        )
        .toList();
    if (typed.isEmpty ||
        entries.any(
          (DropdownMenuEntry<String> e) => e.label.toLowerCase() == typed,
        )) {
      return matches;
    }
    final String name = filter.trim();
    return <DropdownMenuEntry<String>>[
      ...matches,
      DropdownMenuEntry<String>(
        value: '$_createNamed$name',
        label: '${AppLocalizations.of(context)!.groupNewFolder}: $name',
        leadingIcon: PhosphorIcon(PhosphorIcons.folderPlus(), size: Sizes.p20),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return BlocBuilder<ProfileGroupBloc, ProfileGroupState>(
      builder: (BuildContext context, ProfileGroupState groups) {
        if (groups is! ProfileGroupsLoaded) return gap0;
        final ProfileFormFolder chosen = context
            .watch<ProfileFormFolderCubit>()
            .state;
        final ProfileGroup? folder = groups.data.groupById(
          chosen.groupId ?? '',
        );
        final String selection = chosen.newName != null
            ? _newFolder
            : folder?.uuid ?? _noFolder;
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
                  // Rebuilt on a rename: DropdownMenu reads its selection once.
                  key: ValueKey<String>(
                    'ProfileFolderSelector-$selection-${folder?.name}-'
                    '${chosen.newName}-$_resets',
                  ),
                  controller: _text,
                  focusNode: _focus,
                  initialSelection: selection,
                  enableFilter: true,
                  filterCallback: _filter,
                  expandedInsets: EdgeInsets.zero,
                  dropdownMenuEntries: <DropdownMenuEntry<String>>[
                    DropdownMenuEntry<String>(
                      value: _noFolder,
                      label: strings.groupNoFolder,
                    ),
                    DropdownMenuEntry<String>(
                      value: _createFolder,
                      label: strings.groupNewFolder,
                      leadingIcon: PhosphorIcon(
                        PhosphorIcons.folderPlus(),
                        size: Sizes.p20,
                      ),
                    ),
                    if (chosen.newName != null)
                      DropdownMenuEntry<String>(
                        value: _newFolder,
                        label: chosen.newName!,
                      ),
                    for (final ProfileGroup group in groups.groups)
                      DropdownMenuEntry<String>(
                        value: group.uuid,
                        label: group.name,
                      ),
                  ],
                  onSelected: (String? value) {
                    if (value == null || value == _newFolder) return;
                    final ProfileFormFolderCubit cubit = context
                        .read<ProfileFormFolderCubit>();
                    if (value == _createFolder) {
                      _create();
                    } else if (value.startsWith(_createNamed)) {
                      cubit.create(value.substring(_createNamed.length));
                    } else {
                      cubit.choose(value == _noFolder ? null : value);
                    }
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
