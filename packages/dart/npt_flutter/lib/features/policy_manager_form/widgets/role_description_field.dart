import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_event.dart';
import 'form_field_widget.dart';

class RoleDescriptionField extends StatefulWidget {
  final Role role;
  final bool isEditing;

  const RoleDescriptionField({super.key, required this.role, required this.isEditing});

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
      _controller.text = widget.role.description;
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
      label: 'Description',
      controller: _controller,
      enabled: widget.isEditing,
      maxLines: 3,
      onChanged: (value) {
        final updatedRole = Role(
          id: widget.role.id,
          name: widget.role.name,
          description: value,
          daemonAtSigns: widget.role.daemonAtSigns,
          devices: widget.role.devices,
          deviceGroups: widget.role.deviceGroups,
          userAtSigns: widget.role.userAtSigns,
        );
        context.read<PolicyManagerBloc>().add(PolicyManagerSave(updatedRole));
      },
    );
  }
}