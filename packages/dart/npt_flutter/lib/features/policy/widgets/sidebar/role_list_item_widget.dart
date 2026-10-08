import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import '../../../../styles/app_color.dart';
import '../../../../styles/sizes.dart';
import '../../cubit/policy_cubit.dart';
import '../../models/policy.dart';

class RoleListItemWidget extends StatelessWidget {
  final FetchedRole role;

  const RoleListItemWidget({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocBuilder<PolicyCubit, PolicyState>(
      builder: (context, state) {
        final isInEditMode =
            state is PolicyEditingRole || state is PolicyCreatingRole;
        final isSelected =
            (state is PolicyViewingRole && state.selectedRole.id == role.id) ||
            (state is PolicyEditingRole && state.selectedRole.id == role.id);
        final isDisabled = isInEditMode;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: SizedBox(
            height: 80,
            width: double.infinity,
            child: Card(
              margin: EdgeInsets.zero,

              elevation: isSelected ? 2 : 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Sizes.p8),
                side: isSelected
                    ? BorderSide(
                        color: AppColor.primaryColor.withValues(alpha: 1),
                        width: 4,
                      )
                    : BorderSide.none,
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: Sizes.p12,
                  vertical: Sizes.p4,
                ),
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
                  role.description.isEmpty
                      ? strings.noDescription
                      : role.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColor.onSurfaceColor),
                ),
                onTap: isDisabled
                    ? null
                    : () {
                        context.read<PolicyCubit>().selectRoleForViewing(
                          role.id,
                        );
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
