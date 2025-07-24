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
import 'logs_section.dart';
import '../services/policy_log_monitor_service.dart';

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
  bool _isSaving = false;
  final PolicyLogMonitorService _monitorService = PolicyLogMonitorService.getInstance();

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    // Automatically start editing if this is a new role (empty name)
    _isEditing = widget.role.name.isEmpty;
    
    // Start monitoring for device names in this role
    _startMonitoring();
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
      
      // Restart monitoring for the new role's device names
      _startMonitoring();
    }
  }

  @override
  void dispose() {
    // Stop monitoring and clear logs when leaving the form
    _stopMonitoring();
    super.dispose();
  }

  void _startMonitoring() {
    // Clear previous logs and start monitoring device names
    _monitorService.clearLogs();
    final deviceNames = _currentRole.devices.map((device) => device.name).toList();
    if (deviceNames.isNotEmpty) {
      _monitorService.startMonitoring(deviceNames);
    }
  }

  void _stopMonitoring() {
    _monitorService.stopMonitoring();
    _monitorService.clearLogs();
  }

  void _showDeleteConfirmation(BuildContext context) {
    final bloc = context.read<PolicyManagerBloc>();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Role'),
          content: Text('Are you sure you want to delete the role "${_currentRole.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                bloc.add(PolicyManagerDeleteRole(_currentRole.id ?? ''));
                setState(() => _isEditing = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PolicyManagerBloc, PolicyManagerState>(
      listener: (context, state) {
        // Exit editing mode when save operation completes successfully
        if (_isSaving && state is PolicyManagerLoaded) {
          setState(() {
            _isEditing = false;
            _isSaving = false;
          });
        } else if (_isSaving && state is PolicyManagerError) {
          setState(() {
            _isSaving = false;
          });
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: Padding(
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
                ElevatedButton(
                  onPressed: () => _showDeleteConfirmation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Delete'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _isSaving = true);
                    // Distinguish between creating new role vs updating existing role
                    if (_currentRole.id == null || _currentRole.id!.isEmpty) {
                      // Creating a new role
                      context.read<PolicyManagerBloc>().add(PolicyManagerCreateRole(_currentRole));
                    } else {
                      // Updating an existing role
                      context.read<PolicyManagerBloc>().add(PolicyManagerUpdateRole(_currentRole));
                    }
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
                  // Row 1: Name and Description
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
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 24),
                  // Logs section
                  const LogsSection(),
                ],
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }
}