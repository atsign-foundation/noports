import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/app_color.dart';

/// Prompts for a folder name. Pops with the trimmed name, or null on cancel.
class ProfileFolderNameDialog extends StatefulWidget {
  static const int maxLength = 64;

  final String title;
  final String? initialName;

  /// Refused, ignoring case.
  final Iterable<String> takenNames;
  const ProfileFolderNameDialog({
    required this.title,
    this.initialName,
    this.takenNames = const <String>[],
    super.key,
  });

  @override
  State<ProfileFolderNameDialog> createState() =>
      _ProfileFolderNameDialogState();
}

class _ProfileFolderNameDialogState extends State<ProfileFolderNameDialog> {
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
          key: const Key('ProfileFolderNameDialog-TextFormField'),
          controller: _controller,
          autofocus: true,
          maxLength: ProfileFolderNameDialog.maxLength,
          decoration: InputDecoration(hintText: strings.folderName),
          validator: (String? value) {
            if (value == null || value.trim().isEmpty) {
              return strings.folderNameRequired;
            }
            final String name = value.trim().toLowerCase();
            if (widget.takenNames.any((String n) => n.toLowerCase() == name)) {
              return strings.folderNameTaken;
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
