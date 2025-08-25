import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../policy/cubit/policy_cubit.dart';
import '../../policy/models/policy.dart';
import '../../../styles/app_color.dart';
import '../../../styles/sizes.dart';

class RoleListItemWidget extends StatelessWidget {
  final Role role;

  const RoleListItemWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        final isInEditMode = state is PolicyLoaded && state.isInEditMode;
        final isLogsView = state is PolicyLoaded && state.isLogsViewing;
        final isSelected = state is PolicyLoaded && 
            state.hasSelectedRole && 
            state.selectedRole?.id == role.id;
        final isDisabled = isInEditMode && !isLogsView;
        
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,
              color: isSelected ? AppColor.primaryColor.withValues(alpha: 0.1) : Colors.white,
              elevation: isSelected ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.zero,
                side: isSelected 
                    ? const BorderSide(color: AppColor.primaryColor, width: 2)
                    : BorderSide.none,
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
                  context.read<PolicyCubit>().selectRoleForViewing(role.id ?? '');
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