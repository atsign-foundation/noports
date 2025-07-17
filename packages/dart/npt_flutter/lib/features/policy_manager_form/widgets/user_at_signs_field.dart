import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_event.dart';
import 'form_field_widget.dart';

class UserAtSignsField extends StatefulWidget {
  final Role role;
  final bool isEditing;

  const UserAtSignsField({super.key, required this.role, required this.isEditing});

  @override
  State<UserAtSignsField> createState() => _UserAtSignsFieldState();
}

class _UserAtSignsFieldState extends State<UserAtSignsField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.role.userAtSigns.join(', '));
  }

  @override
  void didUpdateWidget(UserAtSignsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.userAtSigns != widget.role.userAtSigns) {
      _controller.text = widget.role.userAtSigns.join(', ');
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
      label: 'User AtSigns',
      controller: _controller,
      enabled: widget.isEditing,
      helperText: 'Comma-separated list of user atSigns',
      onChanged: (value) {
        final atSigns = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final updatedRole = Role(
          id: widget.role.id,
          name: widget.role.name,
          description: widget.role.description,
          daemonAtSigns: widget.role.daemonAtSigns,
          devices: widget.role.devices,
          deviceGroups: widget.role.deviceGroups,
          userAtSigns: atSigns,
        );
        context.read<PolicyManagerBloc>().add(PolicyManagerSaveRole(updatedRole));
      },
    );
  }
}