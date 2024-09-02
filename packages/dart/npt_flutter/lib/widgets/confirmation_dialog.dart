import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String message;
  final VoidCallback action;
  const ConfirmationDialog(this.message, this.action, {super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
        child: Column(
      children: [
        Text(message),
        Row(
          children: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                action();
                Navigator.of(context).pop();
              },
              child: const Text("Confirm"),
            ),
          ],
        ),
      ],
    ));
  }
}
