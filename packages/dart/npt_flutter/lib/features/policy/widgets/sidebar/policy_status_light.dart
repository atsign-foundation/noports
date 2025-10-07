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
      return _StatusIndicatorData(
        color: state.lightState == LightState.green
            ? AppColor.successColor
            : AppColor.errorColor,
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
      LightState.red => 'Heartbeat unavailable',
      LightState.clear => 'Heartbeat unknown'
    };
  }
}

class _StatusIndicatorData {
  const _StatusIndicatorData({required this.color, required this.tooltip});

  final Color color;
  final String tooltip;
}
