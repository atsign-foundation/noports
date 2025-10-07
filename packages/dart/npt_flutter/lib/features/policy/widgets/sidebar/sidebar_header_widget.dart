import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';

import '../../cubit/policy_cubit.dart';
import '../../cubit/status_light/policy_status_light_cubit.dart';
import 'policy_status_light.dart';

class SidebarHeaderWidget extends StatelessWidget {
  const SidebarHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PolicyStatusLightCubit(),
      child: BlocBuilder<PolicyStatusLightCubit, PolicyStatusLightState>(
        builder: (context, state) {
          final policyCubit = context.read<PolicyStatusLightCubit>();
          policyCubit.loadStatusLight();
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
                const PolicyStatusLight(),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // this is the refresh button
                    context.read<PolicyCubit>().loadRoles();
                    context.read<PolicyStatusLightCubit>().forceHeartbeat();
                  },
                  tooltip: 'Refresh roles',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
