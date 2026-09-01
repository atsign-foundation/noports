import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../styles/app_color.dart';
import '../../cubit/status_light/policy_status_light_cubit.dart';
import '../../cubit/status_light/policy_status_light_state.dart';
import 'status_light.dart';

class PolicyStatusLight extends StatelessWidget {
  const PolicyStatusLight({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PolicyStatusLightCubit, PolicyStatusLightState>(
      builder: (context, state) {
        final _StatusIndicatorData data = _resolveStateData(state);

        return MouseRegion(
          onEnter: (_) {
            if (state is! PolicyStatusLightLoading) {
              context.read<PolicyStatusLightCubit>().loadStatusLight();
            }
          },
          child: Tooltip(
            message: data.tooltip,
            waitDuration: const Duration(milliseconds: 400),
            child: Semantics(
              label: data.tooltip,
              child: StatusLight(color: data.color),
            ),
          ),
        );
      },
    );
  }

  _StatusIndicatorData _resolveStateData(PolicyStatusLightState state) {
    if (state is PolicyStatusLightLoaded) {
      final Color color = switch (state.lightState) {
        LightState.green => AppColor.successColor,
        LightState.yellow => AppColor.warningColor,
        LightState.red => AppColor.errorColor,
        LightState.clear => AppColor.greyColor,
      };
      return _StatusIndicatorData(
        color: color,
        tooltip: state.message ?? _defaultMessage(state.lightState),
      );
    }

    return const _StatusIndicatorData(
      color: AppColor.greyColor,
      tooltip: '',
    );
  }

  String _defaultMessage(LightState lightState) {
    return switch (lightState) {
      LightState.green => 'Heartbeat healthy',
      LightState.yellow => 'Server version outdated',
      LightState.red => 'Heartbeat unavailable',
      LightState.clear => 'Heartbeat unknown',
    };
  }
}

class _StatusIndicatorData {
  const _StatusIndicatorData({required this.color, required this.tooltip});

  final Color color;
  final String tooltip;
}
