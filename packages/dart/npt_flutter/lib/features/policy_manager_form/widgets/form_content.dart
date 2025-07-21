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
import 'device_list_widget.dart';
import 'device_group_list_widget.dart';

class FormContent extends StatefulWidget {
  final Role role;
  final PolicyManagerLoaded state;

  const FormContent({super.key, required this.role, required this.state});

  @override
  State<FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<FormContent> {
  bool _isEditing = false;
  late Role _currentRole;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    // Automatically start editing if this is a new role (empty name)
    _isEditing = widget.role.name.isEmpty;
  }

  @override
  void didUpdateWidget(FormContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role) {
      _currentRole = widget.role;
      // Automatically start editing if this is a new role (empty name)
      if (widget.role.name.isEmpty) {
        _isEditing = true;
      }
    }
  }

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
                    context.read<PolicyManagerBloc>().add(PolicyManagerUpdateRole(_currentRole));
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
                  // Name and Description at the top
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: RoleNameField(
                          role: _currentRole,
                          isEditing: _isEditing,
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: value,
                                description: _currentRole.description,
                                daemonAtSigns: _currentRole.daemonAtSigns,
                                devices: _currentRole.devices,
                                deviceGroups: _currentRole.deviceGroups,
                                userAtSigns: _currentRole.userAtSigns,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: RoleDescriptionField(
                          role: _currentRole,
                          isEditing: _isEditing,
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: _currentRole.name,
                                description: value,
                                daemonAtSigns: _currentRole.daemonAtSigns,
                                devices: _currentRole.devices,
                                deviceGroups: _currentRole.deviceGroups,
                                userAtSigns: _currentRole.userAtSigns,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Row 2: User AtSigns and Device AtSigns
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: UserAtSignsField(
                          role: _currentRole,
                          isEditing: _isEditing,
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: _currentRole.name,
                                description: _currentRole.description,
                                daemonAtSigns: _currentRole.daemonAtSigns,
                                devices: _currentRole.devices,
                                deviceGroups: _currentRole.deviceGroups,
                                userAtSigns: value,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DaemonAtSignsField(
                          role: _currentRole,
                          isEditing: _isEditing,
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: _currentRole.name,
                                description: _currentRole.description,
                                daemonAtSigns: value,
                                devices: _currentRole.devices,
                                deviceGroups: _currentRole.deviceGroups,
                                userAtSigns: _currentRole.userAtSigns,
                              );
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Row 3: Devices and Device Groups
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: DeviceListWidget(
                          label: 'Devices',
                          devices: _currentRole.devices,
                          isEditing: _isEditing,
                          tooltip: 'A device name string like "default" that is under a device atSign. A device atSign can have multiple device names, device names help distinguish individual device daemon processes. Adding a device name here will allow tunnels to be established from the user atSigns to this device atSign/device name pair.',
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: _currentRole.name,
                                description: _currentRole.description,
                                daemonAtSigns: _currentRole.daemonAtSigns,
                                devices: value,
                                deviceGroups: _currentRole.deviceGroups,
                                userAtSigns: _currentRole.userAtSigns,
                              );
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DeviceGroupListWidget(
                          label: 'Device Groups',
                          deviceGroups: _currentRole.deviceGroups,
                          isEditing: _isEditing,
                          tooltip: 'Daemon processes that specify the --dg option with a string will allow connections from user to the specified host:ports',
                          onChanged: (value) {
                            setState(() {
                              _currentRole = Role(
                                id: _currentRole.id,
                                name: _currentRole.name,
                                description: _currentRole.description,
                                daemonAtSigns: _currentRole.daemonAtSigns,
                                devices: _currentRole.devices,
                                deviceGroups: value,
                                userAtSigns: _currentRole.userAtSigns,
                              );
                            });
                          },
                        ),
                      ),
                    ],
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