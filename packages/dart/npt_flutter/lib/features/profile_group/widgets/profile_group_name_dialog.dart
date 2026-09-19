import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';

/// Prompts for a folder name. Pops with the trimmed name, or null on cancel.
class ProfileGroupNameDialog extends StatefulWidget {
  final String title;
  final String? initialName;
  const ProfileGroupNameDialog({
    required this.title,
    this.initialName,
    super.key,
  });

  @override
  State<ProfileGroupNameDialog> createState() => _ProfileGroupNameDialogState();
}

class _ProfileGroupNameDialogState extends State<ProfileGroupNameDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations strings = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('ProfileGroupNameDialog-TextFormField'),
          controller: _controller,
          autofocus: true,
          maxLength: 64,
          decoration: InputDecoration(hintText: strings.groupFolderName),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return strings.groupFolderNameRequired;
            }
            return null;
          },
          onFieldSubmitted: (String _) => _submit(),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: AppColor.primaryColor),
          onPressed: _submit,
          child: Text(strings.save),
        ),
      ],
    );
  }
}
