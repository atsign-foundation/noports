import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/models/policy.dart';
import '../cubit/policy_manager_form_cubit.dart';
import '../cubit/policy_manager_form_state.dart';

class PolicyManagerFormView extends StatelessWidget {
  final Role role;

  const PolicyManagerFormView({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerFormCubit()..loadRole(role),
      child: const PolicyManagerFormContent(),
    );
  }
}

class PolicyManagerFormContent extends StatefulWidget {
  const PolicyManagerFormContent({super.key});

  @override
  State<PolicyManagerFormContent> createState() => _PolicyManagerFormContentState();
}

class _PolicyManagerFormContentState extends State<PolicyManagerFormContent> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _daemonAtSignsController;
  late TextEditingController _userAtSignsController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _daemonAtSignsController = TextEditingController();
    _userAtSignsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _daemonAtSignsController.dispose();
    _userAtSignsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyManagerFormCubit, PolicyManagerFormState>(
      builder: (context, state) {
        if (state is PolicyManagerFormLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is PolicyManagerFormError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error: ${state.message}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        } else if (state is PolicyManagerFormLoaded) {
          return _buildForm(state);
        } else {
          return const Center(
            child: Text('No role selected'),
          );
        }
      },
    );
  }

  Widget _buildForm(PolicyManagerFormLoaded state) {
    final role = state.role;
    
    // Update controllers when role changes
    _nameController.text = role.name;
    _descriptionController.text = role.description;
    _daemonAtSignsController.text = role.daemonAtSigns.join(', ');
    _userAtSignsController.text = role.userAtSigns.join(', ');

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
              if (state.isEditing) ...[
                TextButton(
                  onPressed: () => context.read<PolicyManagerFormCubit>().stopEditing(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: Save changes
                    context.read<PolicyManagerFormCubit>().stopEditing();
                  },
                  child: const Text('Save'),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: () => context.read<PolicyManagerFormCubit>().startEditing(),
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
                  _buildFormField(
                    label: 'Role Name',
                    controller: _nameController,
                    enabled: state.isEditing,
                    onChanged: (value) => context.read<PolicyManagerFormCubit>().updateRoleName(value),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: 'Description',
                    controller: _descriptionController,
                    enabled: state.isEditing,
                    maxLines: 3,
                    onChanged: (value) => context.read<PolicyManagerFormCubit>().updateRoleDescription(value),
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: 'Daemon AtSigns',
                    controller: _daemonAtSignsController,
                    enabled: state.isEditing,
                    helperText: 'Comma-separated list of daemon atSigns',
                    onChanged: (value) {
                      final atSigns = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      context.read<PolicyManagerFormCubit>().updateDaemonAtSigns(atSigns);
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    label: 'User AtSigns',
                    controller: _userAtSignsController,
                    enabled: state.isEditing,
                    helperText: 'Comma-separated list of user atSigns',
                    onChanged: (value) {
                      final atSigns = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                      context.read<PolicyManagerFormCubit>().updateUserAtSigns(atSigns);
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildDevicesSection(role.devices, state.isEditing),
                  const SizedBox(height: 24),
                  _buildDeviceGroupsSection(role.deviceGroups, state.isEditing),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required bool enabled,
    String? helperText,
    int maxLines = 1,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helperText,
            filled: !enabled,
            fillColor: enabled ? null : Colors.grey[100],
          ),
        ),
      ],
    );
  }

  Widget _buildDevicesSection(List<Device> devices, bool isEditing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Devices',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                  // TODO: Add device functionality
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Device'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (devices.isEmpty)
          const Text(
            'No devices configured',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...devices.map((device) => _buildDeviceCard(device, isEditing)),
      ],
    );
  }

  Widget _buildDeviceCard(Device device, bool isEditing) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.computer),
        title: Text(device.name),
        subtitle: Text('Permit Opens: ${device.permitOpens.join(', ')}'),
        trailing: isEditing
            ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  // TODO: Remove device functionality
                },
              )
            : null,
      ),
    );
  }

  Widget _buildDeviceGroupsSection(List<DeviceGroup> deviceGroups, bool isEditing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Device Groups',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (isEditing)
              TextButton.icon(
                onPressed: () {
                  // TODO: Add device group functionality
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Group'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (deviceGroups.isEmpty)
          const Text(
            'No device groups configured',
            style: TextStyle(color: Colors.grey),
          )
        else
          ...deviceGroups.map((group) => _buildDeviceGroupCard(group, isEditing)),
      ],
    );
  }

  Widget _buildDeviceGroupCard(DeviceGroup group, bool isEditing) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.group_work),
        title: Text(group.name),
        subtitle: Text('Permit Opens: ${group.permitOpens.join(', ')}'),
        trailing: isEditing
            ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  // TODO: Remove device group functionality
                },
              )
            : null,
      ),
    );
  }
}