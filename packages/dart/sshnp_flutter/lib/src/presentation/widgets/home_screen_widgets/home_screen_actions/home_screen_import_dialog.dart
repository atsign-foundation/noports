import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:sshnp_flutter/src/presentation/widgets/profile_screen_widgets/profile_form/custom_text_form_field.dart';
import 'package:sshnp_flutter/src/utility/form_validator.dart';

class HomeScreenImportDialog extends StatefulWidget {
  final void Function(String?) setValue;

  final String? initialName;
  const HomeScreenImportDialog(this.setValue, {this.initialName, super.key});

  @override
  State<HomeScreenImportDialog> createState() => _HomeScreenImportDialogState();
}

class _HomeScreenImportDialogState extends State<HomeScreenImportDialog> {
  final GlobalKey<FormState> _formkey = GlobalKey<FormState>();
  String? result;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(strings.importProfile),
      content: Form(
        key: _formkey,
        child: CustomTextFormField(
          initialValue: widget.initialName,
          labelText: strings.profileName('required'),
          onSaved: (value) {
            result = value;
          },
          validator: FormValidator.validateProfileNameField,
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text(strings.cancelButton,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(decoration: TextDecoration.underline)),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formkey.currentState!.validate()) {
              widget.setValue(result);
              Navigator.of(context).pop();
            }
          },
          style: Theme.of(context).elevatedButtonTheme.style!.copyWith(
                backgroundColor: WidgetStateProperty.all(Colors.black),
              ),
          child: Text(
            strings.submit,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(fontWeight: FontWeight.w700, color: Colors.white),
          ),
        )
      ],
    );
  }
}
