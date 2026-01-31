import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/app_color.dart';

class MultiSelectDialog extends StatelessWidget {
  final String message;
  final String title;
  final Map<String, VoidCallback> actions;
  const MultiSelectDialog({
    required this.title,
    required this.message,
    required this.actions,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(title),
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
            style: TextButton.styleFrom(foregroundColor: AppColor.primaryColor),
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
