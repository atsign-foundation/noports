import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class HomeScreenImportDialog extends StatelessWidget {
  final void Function(String?) setValue;
  final String? initialName;
  const HomeScreenImportDialog(this.setValue, {this.initialName, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController controller = TextEditingController(text: initialName);
    final strings = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Text(strings.importProfile),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: strings.profileName),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancelButton,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(decoration: TextDecoration.underline)),
        ),
        ElevatedButton(
          onPressed: () async {
            setValue(controller.text);
            if (context.mounted) Navigator.of(context).pop();
          },
          style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.black),
              ),
          child: Text(
            strings.submit,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        )
      ],
    );
  }
}
