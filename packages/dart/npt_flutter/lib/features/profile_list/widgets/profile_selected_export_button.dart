import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:npt_flutter/widgets/multi_select_dialog.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ProfileSelectedExportButton extends StatelessWidget {
  const ProfileSelectedExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState, Set<String>>(
      selector: (ProfilesSelectedState state) {
        return state.selected;
      },
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if nothing is selected
        if (selected.isEmpty) return gap0;
        return ElevatedButton.icon(
          onPressed: () {
            var repo = context.read<ProfileRepository>();
            var futureExportableProfileList =
                repo.getProfiles(selected).then((profiles) => profiles.map((profile) => profile.toExportableJson()));
            showDialog(
              context: context,
              builder: (BuildContext context) => MultiSelectDialog(
                strings.profileExportSelectedMessage,
                {
                  'JSON': Export.getExportCallback(
                    ExportableProfileFiletype.json,
                    futureExportableProfileList,
                  ),
                  'YAML': Export.getExportCallback(
                    ExportableProfileFiletype.yaml,
                    futureExportableProfileList,
                  ),
                },
              ),
            );
          },
          label: Text(strings.export),
          icon: PhosphorIcon(PhosphorIcons.export()),
        );
      },
    );
  }
}
