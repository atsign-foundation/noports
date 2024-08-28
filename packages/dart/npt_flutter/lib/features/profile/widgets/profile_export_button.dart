import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/util/export.dart';
import 'package:npt_flutter/widgets/multi_select_dialog.dart';

class ProfileExportButton extends StatelessWidget {
  const ProfileExportButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        var state = context.read<ProfileBloc>().state;
        if (state is! ProfileLoadedState) return;
        var json = state.profile.toExportableJson();

        showDialog(
            context: context,
            builder: (BuildContext context) => MultiSelectDialog(
                    'What filetype would you like to export as?', {
                  'JSON': Export.getExportCallback(
                      ExportableProfileFiletype.json, [json]),
                  'YAML': Export.getExportCallback(
                      ExportableProfileFiletype.yaml, [json]),
                }));
      },
      child: const Text('Export'),
    );
  }
}
