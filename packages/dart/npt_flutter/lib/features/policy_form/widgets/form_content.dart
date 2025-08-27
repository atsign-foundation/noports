import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/models/policy.dart';
import '../../policy/cubit/policy_cubit.dart';
import '../cubit/policy_form_cubit.dart';
import 'role_name_field.dart';
import 'role_description_field.dart';
import 'daemon_at_signs_field.dart';
import 'user_at_signs_field.dart';
import 'device_list_widget.dart';
import 'device_group_list_widget.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class FormContent extends StatelessWidget {
  final Role role;
  final PolicyLoaded state;

  const FormContent({super.key, required this.role, required this.state});



  void _showDeleteConfirmation(BuildContext context, Role currentRole) {
    final formCubit = context.read<PolicyFormCubit>();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Role'),
          content: Text('Are you sure you want to delete the role "${currentRole.name}"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                formCubit.deleteRole();
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
    // Initialize the form cubit with the current role when in edit mode
    if (state.isInEditMode) {
      context.read<PolicyFormCubit>().initializeForm(role: role);
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<PolicyFormCubit, PolicyFormState>(
          listener: (context, formState) {
            if (formState is PolicyFormSuccess) {
              // Handle successful save - could navigate back or show success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(formState.wasNewRole ? 'Role created successfully!' : 'Role updated successfully!'),
                  backgroundColor: AppColor.primaryColor,
                ),
              );
              // Exit editing mode in policy cubit
              context.read<PolicyCubit>().cancelEditing();
            } else if (formState is PolicyFormDeleted) {
              // Handle successful deletion
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Role deleted successfully!'),
                  backgroundColor: AppColor.primaryColor,
                ),
              );
              // Trigger reload and return to browsing
              context.read<PolicyCubit>().loadRoles();
            } else if (formState is PolicyFormError) {
              // Show error message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(formState.message),
                  backgroundColor: AppColor.errorColor,
                ),
              );
            }
          },
        ),
      ],
      child: BlocBuilder<PolicyFormCubit, PolicyFormState>(
        builder: (context, formState) {
          // Default to viewing mode if not in editing form state
          final isEditing = state.isInEditMode && formState is PolicyFormEditing;
          final currentRole = formState is PolicyFormEditing ? formState.currentRole : role;
          final isSaving = formState is PolicyFormEditing ? formState.isSaving : false;
          final canDelete = formState is PolicyFormEditing ? formState.canDelete : false;

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Row(
                    children: [
                      const Spacer(),
                      if (isEditing) ...[
                        if (canDelete) ...[
                          ElevatedButton(
                            onPressed: () => _showDeleteConfirmation(context, currentRole),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.errorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Delete'),
                          ),
                          const SizedBox(width: Sizes.p8),
                        ],
                        TextButton(
                          onPressed: isSaving ? null : () {
                            context.read<PolicyFormCubit>().cancelEditing();
                            context.read<PolicyCubit>().cancelEditing();
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: Sizes.p8),
                        ElevatedButton(
                          onPressed: isSaving ? null : () {
                            context.read<PolicyFormCubit>().saveRole();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColor.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: isSaving 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save'),
                        ),
                      ] else ...[
                        ElevatedButton(
                          onPressed: () {
                            context.read<PolicyCubit>().startEditingRole(role.id ?? '');
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
                                role: currentRole,
                                isEditing: isEditing,
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateRoleName(value);
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: RoleDescriptionField(
                                role: currentRole,
                                isEditing: isEditing,
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateRoleDescription(value);
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
                                role: currentRole,
                                isEditing: isEditing,
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateDaemonAtSigns(value);
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: DeviceListWidget(
                                label: 'Devices',
                                devices: currentRole.devices,
                                isEditing: isEditing,
                                tooltip: 'A device name string like "default" that is under a device atSign. A device atSign can have multiple device names, device names help distinguish individual device daemon processes. Adding a device name here will allow tunnels to be established from the user atSigns to this device atSign/device name pair.',
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateDevices(value);
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: DeviceGroupListWidget(
                                label: 'Device Groups',
                                deviceGroups: currentRole.deviceGroups,
                                isEditing: isEditing,
                                tooltip: 'Daemon processes that specify the --dg option with a string will allow connections from user to the specified host:ports',
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateDeviceGroups(value);
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
                                role: currentRole,
                                isEditing: isEditing,
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateUserAtSigns(value);
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
        },
      ),
    );
  }
}