import 'package:flutter/material.dart';
import '../../cubit/policy_cubit.dart';
import '../../models/policy.dart';
import '../../../../styles/app_color.dart';
import '../../../../styles/sizes.dart';
import 'role_list_item_widget.dart';

class RolesListWidget extends StatelessWidget {
  final PolicyState state;

  const RolesListWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (state is PolicyLoading) {
      return const Center(child: CircularProgressIndicator());
    } else if (state is PolicyError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: AppColor.errorColor),
            gapH8,
            Text(
              'Error: ${(state as PolicyError).message}',
              style: const TextStyle(color: AppColor.errorColor),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else if (state is PolicyLoaded) {
      return _buildLoadedRolesList((state as PolicyLoaded).roles, context);
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
        return RoleListItemWidget(role: role);
      },
    );
  }
}