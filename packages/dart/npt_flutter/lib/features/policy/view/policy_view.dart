import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/features.dart';
import 'package:npt_flutter/features/policy/widgets/sidebar/policy_roles_sidebar.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';
import '../../../widgets/custom_card.dart';
import '../../policy_form/cubit/policy_form_cubit.dart';
import '../../policy_form/view/policy_form_view.dart';
import '../../policy_logs/cubit/policy_logs_cubit.dart';
import '../../policy_logs/widgets/logs_viewer.dart';

class PolicyView extends StatelessWidget {
  final Atsign atsign;
  const PolicyView({super.key, required this.atsign});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        return PolicyContent(atsign: atsign);
      },
    );
  }
}

class PolicyContent extends StatelessWidget {
  final Atsign atsign;
  const PolicyContent({super.key, required this.atsign});

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
                        height:
                            deviceSize.height * Sizes.dashboardCardHeightFactor,
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
      PolicyViewingRole(:final selectedRole) => _buildPolicyForm(
        context: context,
        key: ValueKey('policy_form_view_${selectedRole.id}'),
        role: selectedRole,
        isEditing: false,
      ),
      PolicyEditingRole(:final selectedRole) => _buildPolicyForm(
        context: context,
        key: ValueKey('policy_form_edit_${selectedRole.id}'),
        role: selectedRole,
        isEditing: true,
      ),
      PolicyCreatingRole() => _buildPolicyForm(
        context: context,
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
    final strings = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Text(
                strings.policyLogs,
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
    final strings = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.group, size: 64, color: AppColor.onSurfaceColor),
          const SizedBox(height: Sizes.p16),
          Text(
            strings.roleSelectToViewDetails,
            style: const TextStyle(
              fontSize: Sizes.p18,
              color: AppColor.onSurfaceColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicyForm({
    required BuildContext context,
    required Key key,
    required RoleInProgress role,
    required bool isEditing,
  }) {
    final strings = AppLocalizations.of(context)!;
    return BlocProvider(
      key: key,
      create: (context) {
        final cubit = PolicyFormCubit(
          context.read<RoleRepository>(),
          onSuccess: (message, roleId) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: AppColor.primaryColor,
              ),
            );
            context.read<PolicyCubit>().reloadAndSelectRole(roleId, strings);
          },
          onDeleted: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(strings.roleDeletedSuccessfully),
                backgroundColor: AppColor.primaryColor,
              ),
            );
            context.read<PolicyCubit>().loadRoles(strings);
          },
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          cubit.initializeWithRole(role, isEditing: isEditing);
        });
        return cubit;
      },
      child: PolicyFormView(role: role, isEditing: isEditing),
    );
  }
}
