import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:npt_flutter/widgets/multi_select_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../styles/sizes.dart';
import '../cubit/profiles_selected_cubit.dart';

class ProfileListImportButton extends StatelessWidget {
  const ProfileListImportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<
      ProfilesSelectedCubit,
      ProfilesSelectedState,
      Set<String>
    >(
      selector: (state) => state.selected,
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if something is selected
        if (selected.isNotEmpty) return gap0;
        return ElevatedButton.icon(
          onPressed: () async {
            ExportableProfileFiletype? result;
            await showDialog(
              context: context,
              builder: (BuildContext context) => MultiSelectDialog(
                title: strings.profileImportDialogTitle,
                message: strings.profileImportSelectedMessage,
                actions: {
                  strings.importFile: Export.importProfiles,
                  strings.pasteProfile: () {
                    result = ExportableProfileFiletype.json;
                  },
                },
              ),
            );

            if (result == null) return;
            Export.pasteProfile();
          },
          label: Text(strings.import),
          icon: PhosphorIcon(PhosphorIcons.downloadSimple()),
        );
      },
    );
  }
}
