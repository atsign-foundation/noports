import 'package:flutter/material.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../policy/models/policy.dart';
import 'form_field_widget.dart';

class RoleDescriptionField extends StatefulWidget {
  final RoleInProgress role;
  final bool isEditing;
  final Function(String) onChanged;

  const RoleDescriptionField({
    super.key,
    required this.role,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  State<RoleDescriptionField> createState() => _RoleDescriptionFieldState();
}

class _RoleDescriptionFieldState extends State<RoleDescriptionField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.role.description);
  }

  @override
  void didUpdateWidget(RoleDescriptionField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.description != widget.role.description) {
      if (_controller.text != widget.role.description) {
        _controller.text = widget.role.description;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormFieldWidget(
      label: AppLocalizations.of(context)!.description,
      controller: _controller,
      enabled: widget.isEditing,
      maxLines: null,
      onChanged: widget.onChanged,
    );
  }
}
