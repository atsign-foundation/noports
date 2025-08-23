import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy_manager/cubit/policy_manager_cubit.dart';
import '../../policy_manager/models/policy.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class RoleListItemWidget extends StatelessWidget {
  final Role role;

  const RoleListItemWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyManagerCubit, PolicyManagerState>(
      builder: (context, state) {
        final isInEditMode = state is PolicyManagerLoaded && state.isInEditMode;
        final isLogsView = state is PolicyManagerLoaded && state.isLogsViewing;
        final isDisabled = isInEditMode && !isLogsView;
        
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
                  context.read<PolicyManagerCubit>().selectRoleForViewing(role.id ?? '');
                },
                enabled: !isDisabled,
              ),
            ),
          ),
        );
      },
    );
  }
}