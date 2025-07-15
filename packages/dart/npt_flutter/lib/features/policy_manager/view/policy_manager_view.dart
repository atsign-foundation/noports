import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/policy_manager_cubit.dart';
import '../cubit/policy_manager_state.dart';
import '../models/policy.dart';
import '../../policy_manager_form/view/policy_manager_form_view.dart';
import '../shared/dialogs/policy_dialogs.dart';
import '../shared/utils/policy_utils.dart';
import '../shared/widgets/policy_empty_state_widget.dart';
import '../shared/widgets/policy_error_state_widget.dart';
import '../shared/widgets/policy_small_loading_indicator_widget.dart';
import '../shared/widgets/policy_role_list_item_widget.dart';

class PolicyManagerView extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerView({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerCubit(),
      child: PolicyManagerContent(atSign: atSign),
    );
  }
}

class PolicyManagerContent extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerContent({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PolicyManagerCubit, PolicyManagerState>(
      listener: (context, state) {
        if (state is PolicyManagerError) {
          PolicyUtils.showErrorSnackBar(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is PolicyManagerInitial) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is PolicyManagerLoading) {
          return _buildLoadingState(state);
        } else if (state is PolicyManagerError) {
          return Builder(
            builder: (context) => _buildErrorState(context, state),
          );
        } else if (state is PolicyManagerLoaded) {
          return Builder(
            builder: (context) => _buildLoadedState(context, state),
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildLoadingState(PolicyManagerLoading state) {
    return Builder(
      builder: (context) => Row(
        children: [
          // Left Sidebar - Role List with Loading
          Container(
            width: 300,
            decoration: const BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with loading indicator
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey, width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Roles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          const PolicySmallLoadingIndicatorWidget(),
                          const SizedBox(width: 8),
                          const IconButton(
                            icon: Icon(Icons.refresh),
                            onPressed: null, // Disabled during loading
                            tooltip: 'Refresh roles',
                          ),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _showAddRoleDialog(context),
                            tooltip: 'Add new role',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Roles List
                Expanded(
                  child: state.roles.isEmpty
                      ? _buildEmptyState()
                      : _buildRolesList(state.roles, state.selectedRole),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: state.selectedRole == null
                ? _buildEmptyState()
                : PolicyManagerFormView(
                    role: state.selectedRole!,
                    onRoleUpdated: (updatedRole) {
                      context.read<PolicyManagerCubit>().updateSelectedRole(updatedRole);
                    },
                    onSaveSuccess: () {
                      // Handle save success if needed
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, PolicyManagerError state) {
    return PolicyErrorStateWidget(
      message: state.message,
      onRetry: () => context.read<PolicyManagerCubit>().refreshRoles(),
    );
  }

  Widget _buildLoadedState(BuildContext context, PolicyManagerLoaded state) {
    return Row(
      children: [
        // Left Sidebar - Role List
        Container(
          width: 300,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: Colors.grey, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Roles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () => context.read<PolicyManagerCubit>().refreshRoles(),
                          tooltip: 'Refresh roles',
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => _showAddRoleDialog(context),
                          tooltip: 'Add new role',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Roles List
              Expanded(
                child: _buildRolesList(state.roles, state.selectedRole),
              ),
            ],
          ),
        ),
        // Main Content Area
        Expanded(
          child: state.selectedRole == null
              ? _buildEmptyState()
              : PolicyManagerFormView(
                  role: state.selectedRole!,
                  onRoleUpdated: (updatedRole) {
                    context.read<PolicyManagerCubit>().updateSelectedRole(updatedRole);
                  },
                  onSaveSuccess: () {
                    // Handle save success if needed
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const PolicyEmptyStateWidget(
      title: 'No roles found'
    );
  }

  Widget _buildRolesList(List<Role> roles, Role? selectedRole) {
    return ListView.builder(
      itemCount: roles.length,
      itemBuilder: (context, index) {
        final role = roles[index];
        final isSelected = selectedRole?.id == role.id;
        
        return PolicyRoleListItemWidget(
          name: role.name,
          description: role.description,
          isSelected: isSelected,
          onTap: () => context.read<PolicyManagerCubit>().selectRole(role),
          onDelete: () => _showDeleteRoleDialog(context, role),
        );
      },
    );
  }

  void _showAddRoleDialog(BuildContext context) async {
    final roleName = await PolicyDialogs.showAddRoleDialog(context);
    if (roleName != null && context.mounted) {
      context.read<PolicyManagerCubit>().addRole(roleName);
    }
  }

  void _showDeleteRoleDialog(BuildContext context, Role role) async {
    final confirmed = await PolicyDialogs.showDeleteRoleDialog(context, role);
    if (confirmed == true && context.mounted) {
      context.read<PolicyManagerCubit>().deleteRole(role);
    }
  }
}