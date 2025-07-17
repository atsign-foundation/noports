import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_event.dart';
import 'form_field_widget.dart';

class RoleNameField extends StatefulWidget {
  final Role role;
  final bool isEditing;

  const RoleNameField({super.key, required this.role, required this.isEditing});

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
      _controller.text = widget.role.name;
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
      label: 'Role Name',
      controller: _controller,
      enabled: widget.isEditing,
      onChanged: (value) {
        // Update the role in the bloc
        final updatedRole = Role(
          id: widget.role.id,
          name: value,
          description: widget.role.description,
          daemonAtSigns: widget.role.daemonAtSigns,
          devices: widget.role.devices,
          deviceGroups: widget.role.deviceGroups,
          userAtSigns: widget.role.userAtSigns,
        );
        context.read<PolicyManagerBloc>().add(PolicyManagerSaveRole(updatedRole));
      },
    );
  }
}