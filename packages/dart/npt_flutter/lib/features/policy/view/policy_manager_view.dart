import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/policy_manager_cubit.dart';
import '../repositories/role_repository.dart';
import '../../policy_form/view/policy_manager_form_view.dart';
import '../../policy_logs/widgets/logs_viewer.dart';
import '../../policy_logs/cubit/policy_logs_cubit.dart';
import '../../policy_sidebar/policy_manager_roles_sidebar.dart';
import '../../../widgets/custom_card.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class PolicyManagerView extends StatelessWidget {
  final String atSign;
  
  const PolicyManagerView({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyManagerCubit(context.read<RoleRepository>())..loadRoles(),
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
    return BlocBuilder<PolicyManagerCubit, PolicyManagerState>(
      builder: (context, state) {
        return Scaffold(
          body: Row(
            children: [
              const PolicyManagerRolesSidebar(),
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

  Widget _buildMainContent(PolicyManagerState state, BuildContext context) {
    if (state is PolicyManagerLoaded) {
      switch (state.viewMode) {
        case PolicyManagerViewMode.logsViewing:
          return _buildLogsView(context);
          
        case PolicyManagerViewMode.roleViewing:
        case PolicyManagerViewMode.roleEditing:
        case PolicyManagerViewMode.roleCreating:
          if (state.hasSelectedRole) {
            return PolicyManagerFormView(role: state.selectedRole!);
          }
          break;
          
        case PolicyManagerViewMode.rolesBrowsing:
          return _buildBrowsingView(context);
      }
    }
    
    // Fallback view
    return _buildBrowsingView(context);
  }

  Widget _buildLogsView(BuildContext context) {
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
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: BlocProvider(
              create: (context) => PolicyLogsCubit(),
              child: const LogsViewer(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrowsingView(BuildContext context) {
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