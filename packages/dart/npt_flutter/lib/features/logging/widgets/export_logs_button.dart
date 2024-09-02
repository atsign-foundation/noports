import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/logging/logging.dart';

class ExportLogsButton extends StatelessWidget {
  const ExportLogsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () async {
        var list = context.read<LogsCubit>().logs;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Please select a file to export to:',
          fileName: 'NoPorts-Logs-$timestamp.txt',
        );

        if (outputFile == null) return;

        var f = File(outputFile);
        await f.create(recursive: true);
        await f.writeAsString(list.join("\n"));
      },
      child: const Text("Export Logs"),
    );
  }
}
