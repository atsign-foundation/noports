import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/policy_manager_bloc.dart';
import '../bloc/policy_manager_event.dart';
import '../bloc/policy_manager_state.dart';
import '../models/policy.dart';
import '../repositories/role_repository.dart';
import '../../policy_manager_form/view/policy_manager_form_view.dart';
import '../../policy_logs/widgets/logs_viewer.dart';
import '../../../widgets/custom_card.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class PolicyManagerView extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerView({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerBloc(context.read<RoleRepository>())..add(const PolicyManagerLoadingRoles()),
      child: PolicyManagerContent(atSign: atSign),
    );
  }
}

class PolicyManagerContent extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerContent({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    return BlocBuilder<PolicyManagerBloc, PolicyManagerState>(
      builder: (context, state) {
        return Scaffold(
          body: Row(
            children: [
              _buildRolesSidebar(state, context),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: CustomCard.dashboardContent(
                        height: deviceSize.height * Sizes.dashboardCardHeightFactor,
                        width: SizeConfig.setDashboardWidth(),
                        child: _buildMainContent(state, context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRolesSidebar(PolicyManagerState state, BuildContext context) {
    return SizedBox(
      width: 255,
      height: MediaQuery.of(context).size.height,
      child: CustomCard.settingsRail(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(
                    'Roles',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                      context.read<PolicyManagerBloc>().add(const PolicyManagerLoadingRoles());
                    },
                    tooltip: 'Refresh roles',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: BlocBuilder<PolicyManagerBloc, PolicyManagerState>(
                  builder: (context, state) {
                    final isLogsView = state is PolicyManagerViewLogsPageLoaded;
                    return OutlinedButton.icon(
                      onPressed: () {
                        context.read<PolicyManagerBloc>().add(const PolicyManagerShowLogs());
                      },
                      icon: const Icon(Icons.list_alt),
                      label: const Text('View Logs'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isLogsView ? Colors.white : AppColor.primaryColor,
                        backgroundColor: isLogsView ? AppColor.primaryColor : null,
                        side: const BorderSide(color: AppColor.primaryColor),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.zero,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: SizedBox(
                height: 48,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (state is PolicyManagerRoleLoaded && state.isEditing) 
                    ? null 
                    : () {
                        context.read<PolicyManagerBloc>().add(const PolicyManagerStartNewRole());
                      },
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Role'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColor.primaryColor,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
              ),
            ),
            gapH16,
            Expanded(
              child: _buildRolesList(state, context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolesList(PolicyManagerState state, BuildContext context) {
    if (state is PolicyManagerLoading) {
      // If loading state has roles, show them; otherwise show loading spinner
      if (state.roles != null) {
        return _buildLoadedRolesList(state.roles!, context);
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    } else if (state is PolicyManagerError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: AppColor.errorColor),
            gapH8,
            Text(
              'Error: ${state.message}',
              style: const TextStyle(color: AppColor.errorColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (state is PolicyManagerRoleLoaded) {
      return _buildLoadedRolesList(state.roles, context);
    } else if (state is PolicyManagerViewLogsPageLoaded) {
      return _buildLoadedRolesList(state.roles, context);
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildLoadedRolesList(List<Role> roles, BuildContext context) {
    if (roles.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group, size: 48, color: AppColor.onSurfaceColor),
            SizedBox(height: Sizes.p16),
            Text(
              'No roles found',
              style: TextStyle(color: AppColor.onSurfaceColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: roles.length,
      itemBuilder: (context, index) {
        final role = roles[index];
        return _buildRoleListItem(role, context);
      },
    );
  }

  Widget _buildRoleListItem(Role role, BuildContext context) {
    return BlocBuilder<PolicyManagerBloc, PolicyManagerState>(
      builder: (context, state) {
        final isEditing = state is PolicyManagerRoleLoaded && state.isEditing;
        final isLogsView = state is PolicyManagerViewLogsPageLoaded;
        final isDisabled = isEditing && !isLogsView;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              color: Colors.white,
              elevation: 1,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: Sizes.p12, vertical: Sizes.p4),
                title: Text(
                  role.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDisabled ? AppColor.onSurfaceColor : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  role.description.isEmpty ? 'No description' : role.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColor.onSurfaceColor),
                ),
                onTap: isDisabled ? null : () {
                  context.read<PolicyManagerBloc>().add(PolicyManagerRoleSelected(role.id ?? ''));
                },
                enabled: !isDisabled,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMainContent(PolicyManagerState state, BuildContext context) {
    if (state is PolicyManagerViewLogsPageLoaded) {
      // Show logs view
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Text(
                  'Policy Logs',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Logs viewer
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: LogsViewer(),
            ),
          ),
        ],
      );
    }
    
    if (state is PolicyManagerRoleLoaded) {
      // Show role form if a role is selected
      if (state.selectedRole != null) {
        return PolicyManagerFormView(role: state.selectedRole!);
      }
    }
    
    // Default view when no role is selected
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group, size: 64, color: AppColor.onSurfaceColor),
          SizedBox(height: Sizes.p16),
          Text(
            'Select a role to view details',
            style: TextStyle(
              fontSize: Sizes.p18,
              color: AppColor.onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }
}