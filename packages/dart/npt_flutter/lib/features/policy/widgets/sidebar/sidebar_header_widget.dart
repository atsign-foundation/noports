import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

import '../../cubit/policy_cubit.dart';
import '../../cubit/status_light/policy_status_light_cubit.dart';
import 'policy_status_light.dart';

class SidebarHeaderWidget extends StatelessWidget {
  const SidebarHeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocProvider(
      create: (_) => PolicyStatusLightCubit()..loadStatusLight(),
      child: BlocBuilder<PolicyStatusLightCubit, PolicyStatusLightState>(
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(Sizes.p8),
            child: Row(
              children: [
                Text(
                  strings.roles,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                const PolicyStatusLight(),
                gapW12,
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    // this is the refresh button
                    context.read<PolicyCubit>().loadRoles(strings);
                    context.read<PolicyStatusLightCubit>().forceHeartbeat();
                  },
                  tooltip: strings.rolesRefresh,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
