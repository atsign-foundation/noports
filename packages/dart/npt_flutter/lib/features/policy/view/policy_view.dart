import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/policy/widgets/sidebar/policy_roles_sidebar.dart';
import '../cubit/policy_cubit.dart';
import '../models/policy.dart';
import '../repositories/role_repository.dart';
import '../../policy_form/view/policy_form_view.dart';
import '../../policy_logs/widgets/logs_viewer.dart';
import '../../policy_logs/cubit/policy_logs_cubit.dart';
import '../../../widgets/custom_card.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class PolicyView extends StatelessWidget {
  final String atSign;

  const PolicyView({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PolicyCubit(context.read<RoleRepository>())..loadRoles(),
      child: PolicyContent(atSign: atSign),
    );
  }
}

class PolicyContent extends StatelessWidget {
  final String atSign;

  const PolicyContent({super.key, required this.atSign});

  @override
  Widget build(BuildContext context) {
    final deviceSize = MediaQuery.of(context).size;
    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        return Scaffold(
          body: Row(
            children: [
              const PolicyRolesSidebar(),
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

  Widget _buildMainContent(PolicyState state, BuildContext context) {
    return switch (state) {
      PolicyInitial() => _buildBrowsingView(context),
      PolicyViewingLogs() => _buildLogsView(context),
      PolicyViewingRole(:final selectedRole) => PolicyFormView(
        key: ValueKey('policy_form_view_${selectedRole.id}'),
        role: selectedRole,
        isEditing: false,
      ),
      PolicyEditingRole(:final selectedRole) => PolicyFormView(
        key: ValueKey('policy_form_edit_${selectedRole.id}'),
        role: selectedRole,
        isEditing: true,
      ),
      PolicyCreatingRole() => PolicyFormView(
        key: const ValueKey('policy_form_create_new'),
        role: RoleInProgress.empty(),
        isEditing: true,
      ),
      PolicyBrowsingRoles() => _buildBrowsingView(context),
      PolicyLoading() => _buildBrowsingView(context),
      PolicyError() => _buildBrowsingView(context),
    };
  }

  Widget _buildLogsView(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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