import 'package:flutter/material.dart';

class MultiSelectDialog extends StatelessWidget {
  final String message;
  final Map<String, VoidCallback> actions;
  const MultiSelectDialog(this.message, this.actions, {super.key});

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
            ...actions.entries.map(
              (e) => ElevatedButton(
                onPressed: () {
                  e.value();
                  Navigator.of(context).pop();
                },
                child: Text(e.key),
              ),
            ),
          ],
        ),
      ],
    ));
  }
}
