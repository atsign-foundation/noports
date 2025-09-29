import 'dart:convert';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_utils/at_logger.dart';
import 'package:npt_flutter/features/logging/models/logging_bloc.dart';
import 'package:npt_flutter/features/policy/cubit/status_light/policy_status_light_state.dart';

final class PolicyStatusLightCubit extends LoggingCubit<PolicyStatusLightState> {
  PolicyStatusLightCubit() : super(const PolicyStatusLightInitial());

  final AtSignLogger logger = AtSignLogger('PolicyStatusLightCubit');

  Future<void> loadStatusLight() async {
    final AtClient atClient = AtClientManager.getInstance().atClient;

    final AtKey atKey = AtKey()
      ..key = 'heartbeat'
      ..sharedBy = atClient.getCurrentAtSign()
    ;

    final AtValue atValue = await atClient.get(atKey, getRequestOptions: GetRequestOptions()..useRemoteAtServer=true);

    if(atValue.value == null) {
      final String msg = 'Failed to fetch AtKey value of ${atKey.toString()}';
      emit(PolicyStatusLightLoaded(lightState: LightState.red, message: msg));
      logger.severe(msg);
      return;
    }

    dynamic obj = jsonDecode(atValue.value);

    final String timestampIso8601String = obj['timestamp'];

    

  }
}