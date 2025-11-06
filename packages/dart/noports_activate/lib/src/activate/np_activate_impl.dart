import 'package:at_auth/at_auth.dart';
import 'package:at_commons/at_commons.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:noports_activate/src/activate/np_activate_params.dart';

sealed class NPActivate {
  Future<bool> cramAuthenticate(NPActivateParams params);

  Future<AtEnrollmentResponse> enroll(NPActivateParams params);
}

enum NPActivateType { cram, enroll }

class NPActivateImpl implements NPActivate {
  AtOnboardingService? _atOnboardingService;

  @override
  Future<bool> cramAuthenticate(NPActivateParams params) async {
    validateArgs(params, NPActivateType.cram);
    AtOnboardingPreference atOnboardingPreference = AtOnboardingPreference()
      ..cramSecret = params.cram;
    _atOnboardingService = AtOnboardingServiceImpl(
      params.atsign!,
      atOnboardingPreference,
    );
    return await _atOnboardingService!.onboard();
  }

  @override
  Future<AtEnrollmentResponse> enroll(NPActivateParams params) async {
    // needs to overwrite existing onboarding instance
    _atOnboardingService ??= AtOnboardingServiceImpl(
      params.atsign!,
      AtOnboardingPreference(),
    );

    return await _atOnboardingService!.enroll(
      params.appName,
      //concat device name prefix and the otp to generate a unique device name
      '${params.deviceNamePrefix}_${params.otp!}',
      params.otp!,
      params.namespaces,
    );
  }

  void validateArgs(NPActivateParams params, NPActivateType type){
    
  }
}

Future<void> wrappedActivateMain(List<String> args) async {
  NPActivateParams npActivateParams = NPActivateParams().fromArgs(args);
}