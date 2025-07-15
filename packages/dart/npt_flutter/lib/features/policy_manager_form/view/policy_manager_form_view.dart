import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../cubit/policy_manager_form_cubit.dart';
import '../cubit/policy_manager_form_state.dart';
import '../../policy_manager/shared/dialogs/policy_dialogs.dart';
import '../../policy_manager/shared/utils/policy_utils.dart';
import '../../policy_manager/shared/widgets/policy_list_section_widget.dart';

class PolicyManagerFormView extends StatelessWidget {
  final Role role;
  final Function(Role)? onRoleUpdated;
  final VoidCallback? onSaveSuccess;

  const PolicyManagerFormView({
    super.key,
    required this.role,
    this.onRoleUpdated,
    this.onSaveSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerFormCubit()..loadRole(role),
      child: PolicyManagerFormContent(
        onRoleUpdated: onRoleUpdated,
        onSaveSuccess: onSaveSuccess,
      ),
    );
  }
}

class PolicyManagerFormContent extends StatelessWidget {
  final Function(Role)? onRoleUpdated;
  final VoidCallback? onSaveSuccess;

  const PolicyManagerFormContent({
    super.key,
    this.onRoleUpdated,
    this.onSaveSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PolicyManagerFormCubit, PolicyManagerFormState>(
      listener: (context, state) {
        if (state is PolicyManagerFormSaved) {
          onSaveSuccess?.call();
          PolicyUtils.showSuccessSnackBar(context, 'Role saved successfully');
        } else if (state is PolicyManagerFormError) {
          PolicyUtils.showErrorSnackBar(context, state.message);
        } else if (state is PolicyManagerFormLoaded) {
          onRoleUpdated?.call(state.role);
        }
      },
      builder: (context, state) {
        if (state is PolicyManagerFormLoaded) {
          return _buildForm(context, state);
        } else if (state is PolicyManagerFormSaving) {
          return _buildSavingState(context, state);
        } else if (state is PolicyManagerFormError && state.role != null) {
          return _buildForm(context, PolicyManagerFormLoaded(role: state.role!));
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildForm(BuildContext context, PolicyManagerFormLoaded state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Edit Role',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (state.hasUnsavedChanges)
                const Icon(
                  Icons.circle,
                  color: Colors.orange,
                  size: 12,
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: state.hasUnsavedChanges 
                    ? () => context.read<PolicyManagerFormCubit>().saveRole()
                    : null,
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Form Content
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 800;
                
                if (isWideScreen) {
                  // Wide screen - side by side layout
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left Column - Basic Info
                      Expanded(
                        flex: 1,
                        child: _buildBasicInfoSection(context, state),
                      ),
                      const SizedBox(width: 24),
                      // Right Column - Lists in Grid
                      Expanded(
                        flex: 2,
                        child: _buildPermissionsSection(context, state),
                      ),
                    ],
                  );
                } else {
                  // Narrow screen - stacked layout
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      _buildBasicInfoSection(context, state),
                      const SizedBox(height: 24),
                      // Permissions Section
                      Expanded(
                        child: _buildPermissionsSection(context, state),
                      ),
                    ],
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context, PolicyManagerFormLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Basic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Name Field
        TextFormField(
          key: ValueKey('name_${state.role.id}'),
          initialValue: state.role.name,
          decoration: const InputDecoration(
            labelText: 'Role Name',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) => context.read<PolicyManagerFormCubit>().updateRoleName(value),
        ),
        const SizedBox(height: 16),
        // Description Field
        TextFormField(
          key: ValueKey('description_${state.role.id}'),
          initialValue: state.role.description,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 4,
          onChanged: (value) => context.read<PolicyManagerFormCubit>().updateRoleDescription(value),
        ),
      ],
    );
  }

  Widget _buildPermissionsSection(BuildContext context, PolicyManagerFormLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Permissions & Access',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        // Grid Layout for Lists
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 600 ? 2 : 1;
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: crossAxisCount == 2 ? 1.2 : 0.8,
                children: [
                  // Device AtSigns Section
                  PolicyListSectionWidget(
                    title: 'Device AtSigns',
                    items: state.role.deviceAtSigns.map((e) => e.atSign).toList(),
                    onChanged: (items) => context.read<PolicyManagerFormCubit>().updateDeviceAtSigns(items),
                  ),
                  // Device Names Section
                  PolicyListSectionWidget(
                    title: 'Device Names',
                    items: state.role.deviceNames.map((e) => e.name).toList(),
                    onChanged: (items) => context.read<PolicyManagerFormCubit>().updateDeviceNames(items),
                  ),
                  // Device Groups Section
                  PolicyListSectionWidget(
                    title: 'Device Groups',
                    items: state.role.deviceGroups.map((e) => e.name).toList(),
                    onChanged: (items) => context.read<PolicyManagerFormCubit>().updateDeviceGroups(items),
                  ),
                  // User AtSigns Section
                  PolicyListSectionWidget(
                    title: 'User AtSigns',
                    items: state.role.userAtSigns.map((e) => e.atSign).toList(),
                    onChanged: (items) => context.read<PolicyManagerFormCubit>().updateUserAtSigns(items),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSavingState(BuildContext context, PolicyManagerFormSaving state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Text(
                'Edit Role',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              const ElevatedButton(
                onPressed: null,
                child: Text('Saving...'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Saving role...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                    ),
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