import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class ConfirmationDialog extends StatelessWidget {
  final String message;
  final String actionText;
  final VoidCallback action;
  const ConfirmationDialog({required this.message, required this.action, required this.actionText, super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.alertDialogTitle),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text(strings.cancel),
        ),
        TextButton(
          onPressed: () {
            action();
            Navigator.of(context).pop();
          },
          child: Text(
            actionText,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
