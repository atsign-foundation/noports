import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';

class ImportTypePasteDialog extends StatefulWidget {
  const ImportTypePasteDialog({super.key});

  @override
  State<ImportTypePasteDialog> createState() => _ImportTypePasteDialogState();
}

class _ImportTypePasteDialogState extends State<ImportTypePasteDialog> {
  final TextEditingController _controller = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.pasteProfile),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: Sizes.p20,
        children: [
          Text(strings.pasteProfileDescription),
          SizedBox(
            width: Sizes.p600,
            height: Sizes.p400,
            child: TextField(
              controller: _controller,
              maxLines: 15,
              minLines: 15,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
          child: const Text("Create Profile"),
        ),
      ],
    );
  }
}
