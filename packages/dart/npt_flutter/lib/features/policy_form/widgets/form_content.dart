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

class FormContent extends StatefulWidget {
  final Role role;
  final PolicyLoaded state;

  const FormContent({super.key, required this.role, required this.state});

  @override
  State<FormContent> createState() => _FormContentState();
}

class _FormContentState extends State<FormContent> {
  @override
  void initState() {
    super.initState();
    // Initialize the form when the widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PolicyFormCubit>().initializeForm(role: widget.role);
    });
  }



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

    return BlocListener<PolicyFormCubit, PolicyFormState>(
      listener: (context, formState) {
        if (formState is PolicyFormError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(formState.message),
              backgroundColor: AppColor.errorColor,
            ),
          );
        }
      },
      child: BlocBuilder<PolicyFormCubit, PolicyFormState>(
        builder: (context, formState) {
          if (formState is PolicyFormLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          
          final isEditing = (widget.state is RoleEditingState || widget.state is RoleCreatingState) && formState is PolicyFormEditing;
          final currentRole = formState is PolicyFormEditing ? formState.currentRole : widget.role;
          final isSaving = formState is PolicyFormEditing ? formState.isSaving : false;
          final canDelete = formState is PolicyFormEditingExisting ? formState.canDelete : false;

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
                            context.read<PolicyCubit>().startEditingRole(widget.role.id);
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