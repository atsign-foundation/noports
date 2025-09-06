import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../cubit/policy_cubit.dart';

class SidebarHeaderWidget extends StatelessWidget {
  const SidebarHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              context.read<PolicyCubit>().loadRoles();
            },
            tooltip: 'Refresh roles',
          ),
        ],
      ),
    );
  }
}