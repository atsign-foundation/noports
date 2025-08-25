import 'package:flutter/material.dart';
import '../../policy/models/policy.dart';
import 'form_field_widget.dart';

class RoleNameField extends StatefulWidget {
  final Role role;
  final bool isEditing;
  final Function(String) onChanged;

  const RoleNameField({super.key, required this.role, required this.isEditing, required this.onChanged});

  @override
  State<RoleNameField> createState() => _RoleNameFieldState();
}

class _RoleNameFieldState extends State<RoleNameField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.role.name);
  }

  @override
  void didUpdateWidget(RoleNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.name != widget.role.name) {
      // `only update if the controller text doesn't match the new role name
      // prevents unnecessary text selection
      if (_controller.text != widget.role.name) {
        _controller.text = widget.role.name;
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
      label: 'Name',
      controller: _controller,
      enabled: widget.isEditing,
      onChanged: widget.onChanged,
    );
  }
}