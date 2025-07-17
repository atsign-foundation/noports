import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_event.dart';
import 'form_field_widget.dart';

class DaemonAtSignsField extends StatefulWidget {
  final Role role;
  final bool isEditing;

  const DaemonAtSignsField({super.key, required this.role, required this.isEditing});

  @override
  State<DaemonAtSignsField> createState() => _DaemonAtSignsFieldState();
}

class _DaemonAtSignsFieldState extends State<DaemonAtSignsField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.role.daemonAtSigns.join(', '));
  }

  @override
  void didUpdateWidget(DaemonAtSignsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role.daemonAtSigns != widget.role.daemonAtSigns) {
      _controller.text = widget.role.daemonAtSigns.join(', ');
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
      label: 'Daemon AtSigns',
      controller: _controller,
      enabled: widget.isEditing,
      helperText: 'Comma-separated list of daemon atSigns',
      onChanged: (value) {
        final atSigns = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final updatedRole = Role(
          id: widget.role.id,
          name: widget.role.name,
          description: widget.role.description,
          daemonAtSigns: atSigns,
          devices: widget.role.devices,
          deviceGroups: widget.role.deviceGroups,
          userAtSigns: widget.role.userAtSigns,
        );
        context.read<PolicyManagerBloc>().add(PolicyManagerSave(updatedRole));
      },
    );
  }
}