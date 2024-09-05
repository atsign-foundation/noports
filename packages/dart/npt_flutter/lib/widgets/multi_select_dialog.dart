import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';

class MultiSelectDialog extends StatelessWidget {
  final String message;
  final Map<String, VoidCallback> actions;
  const MultiSelectDialog(this.message, this.actions, {super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.profileExportDialogTitle),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(strings.cancel),
        ),
        ...actions.entries.map(
          (e) => TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColor.primaryColor,
            ),
            onPressed: () {
              e.value();
              Navigator.of(context).pop();
            },
            child: Text(e.key),
          ),
        ),
      ],
    );
  }
}
