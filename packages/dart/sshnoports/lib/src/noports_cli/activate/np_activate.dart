import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate_params.dart';

sealed class NPActivate {
  Future<int> wrappedMain(List<String> args);

  Future<bool> cramAuthenticate(NoportsParams params);

  Future<AtEnrollmentResponse> enroll(NoportsParams params);
}

enum NPActivateType { cram, enroll }

class NPActivateImpl implements NPActivate {
  @override
  Future<int> wrappedMain(List<String> args) async {
    NoportsParams params = NoportsParams.fromArgs(args);
    NPActivateType activateType = _parseAuthType(args[1]);

    switch (activateType) {
      case NPActivateType.cram:
        await cramAuthenticate(params);
        break;
      case NPActivateType.enroll:
        await enroll(params);
    }
    return 0;
  }

  @override
  Future<bool> cramAuthenticate(NoportsParams params) async {
    validateArgs(params, NPActivateType.cram);
    AtOnboardingPreference atOnboardingPreference = AtOnboardingPreference()
      ..cramSecret = params.cram;
    AtOnboardingService onboardingService = AtOnboardingServiceImpl(
      params.atsign,
      atOnboardingPreference,
    );

    return await onboardingService.onboard();
  }

  @override
  Future<AtEnrollmentResponse> enroll(NoportsParams params) async {
    AtOnboardingService onboardingService = AtOnboardingServiceImpl(
      params.atsign,
      AtOnboardingPreference(),
    );

    File? atKeys;
    if (params.atKeysFilePath != null) {
      atKeys = File(params.atKeysFilePath!);
    }
    return await onboardingService.enroll(
        params.appName, params.deviceName!, params.otp!, params.namespaces,
        atKeysFile: atKeys);
  }

  void validateArgs(NoportsParams params, NPActivateType type) {
    switch (type) {
      case NPActivateType.cram:
        if (params.cram == null) {
          throw ArgumentError(
            'Cannot perform CRAM auth without secret',
          );
        }
        break;
      case NPActivateType.enroll:
        if (params.otp == null) {
          throw ArgumentError(
            'Cannot create enrollment without otp',
          );
        }
    }
  }

  static NPActivateType _parseAuthType(String cmd) {
    if (cmd.contains('cram')) {
      return NPActivateType.cram;
    } else if (cmd.contains('enroll')) {
      return NPActivateType.enroll;
    }
    throw ArgumentError('Invalid command: $cmd');
  }
}
