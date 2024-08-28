import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_list/profile_list.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:npt_flutter/widgets/multi_select_dialog.dart';

class ProfileSelectedExportButton extends StatelessWidget {
  const ProfileSelectedExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfilesSelectedCubit, ProfilesSelectedState,
        Set<String>>(
      selector: (ProfilesSelectedState state) {
        return state.selected;
      },
      builder: (BuildContext context, Set<String> selected) {
        // Hide this button if nothing is selected
        if (selected.isEmpty) return const SizedBox();
        return ElevatedButton(
          onPressed: () {
            var repo = context.read<ProfileRepository>();
            var futureExportableProfileList = repo.getProfiles(selected).then(
                (profiles) =>
                    profiles.map((profile) => profile.toExportableJson()));
            showDialog(
              context: context,
              builder: (BuildContext context) => MultiSelectDialog(
                "Are you sure you want to delete the selected profiles?",
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
          child: const Text("Export Selected"),
        );
      },
    );
  }
}
