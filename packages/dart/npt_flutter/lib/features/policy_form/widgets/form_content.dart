import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';
import '../../policy/cubit/policy_cubit.dart';
import '../../policy/models/policy.dart';
import '../cubit/policy_form_cubit.dart';
import 'daemon_at_signs_field.dart';
import 'device_group_list_widget.dart';
import 'device_list_widget.dart';
import 'role_description_field.dart';
import 'role_name_field.dart';
import 'user_at_signs_field.dart';

class FormContent extends StatelessWidget {
  const FormContent({super.key});

  void _showDeleteConfirmation(
    BuildContext context,
    RoleInProgress currentRole,
  ) {
    final formCubit = context.read<PolicyFormCubit>();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        final strings = AppLocalizations.of(dialogContext)!;
        return AlertDialog(
          title: Text(strings.roleDelete),
          content: Text(strings.roleDeleteConfirmation(currentRole.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                formCubit.deleteCurrentRole(strings);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColor.errorColor,
                foregroundColor: Colors.white,
              ),
              child: Text(strings.delete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
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
            return const Center(child: CircularProgressIndicator());
          }

          // Get the current role from the form state
          final currentRole = formState.currentRole;
          if (currentRole == null) {
            return Center(child: Text(strings.roleNotLoaded));
          }

          // Determine if we're in editing mode based on the form state
          final isEditing = formState.isEditingState;
          final isSaving = formState.isSaving;
          final canDelete = formState.canDelete;

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
                            onPressed: () =>
                                _showDeleteConfirmation(context, currentRole),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.errorColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(strings.delete),
                          ),
                          const SizedBox(width: Sizes.p8),
                        ],
                        TextButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  context
                                      .read<PolicyFormCubit>()
                                      .cancelEditing();
                                  context.read<PolicyCubit>().cancelEditing();
                                },
                          child: Text(strings.cancel),
                        ),
                        const SizedBox(width: Sizes.p8),
                        ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  context.read<PolicyFormCubit>().saveRole(
                                    strings,
                                  );
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(strings.save),
                        ),
                      ] else ...[
                        if (currentRole is FetchedRole)
                          ElevatedButton(
                            onPressed: () {
                              final roleId = currentRole.id;
                              context.read<PolicyCubit>().startEditingRole(
                                roleId,
                              );
                              context
                                  .read<PolicyFormCubit>()
                                  .initializeFormExisting(roleId, strings);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColor.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text(strings.edit),
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
                                  context.read<PolicyFormCubit>().updateName(
                                    value,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: RoleDescriptionField(
                                role: currentRole,
                                isEditing: isEditing,
                                onChanged: (value) {
                                  context
                                      .read<PolicyFormCubit>()
                                      .updateDescription(value);
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
                                  context
                                      .read<PolicyFormCubit>()
                                      .updateDaemonAtSigns(value);
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: DeviceListWidget(
                                label: strings.devices,
                                devices: currentRole.devices,
                                isEditing: isEditing,
                                tooltip: strings.devicesTooltip,
                                onChanged: (value) {
                                  context.read<PolicyFormCubit>().updateDevices(
                                    value,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: Sizes.p16),
                            Expanded(
                              child: DeviceGroupListWidget(
                                label: strings.deviceGroups,
                                deviceGroups: currentRole.deviceGroups,
                                isEditing: isEditing,
                                tooltip: strings.deviceGroupTooltip,
                                onChanged: (value) {
                                  context
                                      .read<PolicyFormCubit>()
                                      .updateDeviceGroups(value);
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
                                  context
                                      .read<PolicyFormCubit>()
                                      .updateUserAtSigns(value);
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
