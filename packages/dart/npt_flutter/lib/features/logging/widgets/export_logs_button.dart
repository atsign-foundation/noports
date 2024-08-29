import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/logging/logging.dart';

class ExportLogsButton extends StatelessWidget {
  const ExportLogsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return TextButton.icon(
      onPressed: () async {
        var list = context.read<LogsCubit>().logs;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: strings.selectExportFile,
          fileName: 'NoPorts-${strings.logs}-$timestamp.txt',
        );

        if (outputFile == null) return;

        var f = File(outputFile);
        await f.create(recursive: true);
        await f.writeAsString(list.join("\n"));
      },
      label: Text(strings.exportLogs),
      icon: const Icon(Icons.download),
    );
  }
}
