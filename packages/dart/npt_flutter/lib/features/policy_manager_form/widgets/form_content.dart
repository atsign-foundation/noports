import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../../policy_manager/bloc/policy_manager_bloc.dart';
import '../../policy_manager/bloc/policy_manager_event.dart';
import '../../policy_manager/bloc/policy_manager_state.dart';
import 'role_name_field.dart';
import 'role_description_field.dart';
import 'daemon_at_signs_field.dart';
import 'user_at_signs_field.dart';
import 'devices_section.dart';
import 'device_groups_section.dart';

class FormContent extends StatefulWidget {
  final Role role;
  final PolicyManagerLoaded state;

  const FormContent({super.key, required this.role, required this.state});

  @override
  State<FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<FormContent> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Role Details',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              if (_isEditing) ...[
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    context.read<PolicyManagerBloc>().add(PolicyManagerSaveRole(widget.role));
                    setState(() => _isEditing = false);
                  },
                  child: const Text('Save'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isEditing = true);
                    context.read<PolicyManagerBloc>().add(PolicyManagerStartEditing(widget.role.id ?? ''));
                  },
                  child: const Text('Edit'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoleNameField(
                    role: widget.role,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  RoleDescriptionField(
                    role: widget.role,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  DaemonAtSignsField(
                    role: widget.role,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 16),
                  UserAtSignsField(
                    role: widget.role,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 24),
                  DevicesSection(
                    devices: widget.role.devices,
                    isEditing: _isEditing,
                  ),
                  const SizedBox(height: 24),
                  DeviceGroupsSection(
                    deviceGroups: widget.role.deviceGroups,
                    isEditing: _isEditing,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}