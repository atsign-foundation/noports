import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/cubit/policy_cubit.dart';
import 'role_name_field.dart';
import 'role_description_field.dart';
import 'daemon_at_signs_field.dart';
import 'user_at_signs_field.dart';
import 'device_list_widget.dart';
import 'device_group_list_widget.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class FormContent extends StatefulWidget {
  final Role role;
  final PolicyLoaded state;

  const FormContent({super.key, required this.role, required this.state});

  @override
  State<FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<FormContent> {
  bool _isEditing = false;
  late Role _currentRole;
  late Role _originalRole; // Backup of original role for cancel functionality
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentRole = widget.role;
    _originalRole = widget.role; // Backup original role data
    // Determine editing state from cubit state
    _isEditing = widget.state.isInEditMode;
  }

  @override
  void dispose() {
    super.dispose();
  }


  @override
  void didUpdateWidget(FormContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.role != widget.role || oldWidget.state.viewMode != widget.state.viewMode) {
      _currentRole = widget.role;
      _originalRole = widget.role; // Update backup when role changes
      // Update editing state from cubit state
      _isEditing = widget.state.isInEditMode;
    }
  }

  void _showDeleteConfirmation(BuildContext context) {
    final cubit = context.read<PolicyCubit>();
    
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
                cubit.deleteRole(_currentRole.id ?? '');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.errorColor,
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
    return BlocListener<PolicyCubit, PolicyState>(
      listener: (context, state) {
        // Update local editing state from bloc and handle save completion
        if (state is PolicyLoaded) {
          setState(() {
            // Backup original data when starting to edit
            if (!_isEditing && state.isInEditMode) {
              _originalRole = _currentRole;
            }
            _isEditing = state.isInEditMode;
            if (_isSaving) {
              _isSaving = false;
            }
          });
        } else if (_isSaving && state is PolicyError) {
          setState(() {
            _isSaving = false;
          });
          // Show error message to user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColor.errorColor,
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Row(
              children: [
                const Spacer(),
                if (_isEditing) ...[
                  ElevatedButton(
                    onPressed: () => _showDeleteConfirmation(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.errorColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                  const SizedBox(width: Sizes.p8),
                  TextButton(
                    onPressed: () {
                      // Restore original role data before canceling
                      setState(() {
                        _currentRole = _originalRole;
                      });
                      context.read<PolicyCubit>().cancelEditing();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: Sizes.p8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _isSaving = true);
                      // Distinguish between creating new role vs updating existing role
                      if (_currentRole.id == null || _currentRole.id!.isEmpty) {
                        // Creating a new role
                        context.read<PolicyCubit>().createRole(_currentRole);
                      } else {
                        // Updating an existing role
                        context.read<PolicyCubit>().updateRole(_currentRole);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Save'),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () {
                      context.read<PolicyCubit>().startEditingRole(widget.role.id ?? '');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColor.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Edit'),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Sizes.p24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(right: 8.0),
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
                      const SizedBox(width: Sizes.p16),
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
                  const SizedBox(height: Sizes.p24),
                  // Row 2: Device AtSigns, Devices, Device Groups
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(width: Sizes.p16),
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
                      const SizedBox(width: Sizes.p16),
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
                  const SizedBox(height: Sizes.p24),
                  // Row 3: User AtSigns
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
                    ],
                  ),
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