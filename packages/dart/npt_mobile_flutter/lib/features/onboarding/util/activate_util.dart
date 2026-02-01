import 'dart:convert';
import 'dart:io';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart' hide Response;
import 'package:at_onboarding_flutter/utils/at_onboarding_response_status.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:npt_mobile_flutter/util/onboarding_service.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

const apiBase = '/api/app/v3';

enum NoPortsActivateApiEndpoints {
  login('$apiBase/authenticate/atsign'),
  validate('$apiBase/authenticate/atsign/activate');

  final String path;
  const NoPortsActivateApiEndpoints(this.path);
}

class ActivateUtil {
  final String registrarUrl;
  final String apiKey;
  late final IOClient _http;

  ActivateUtil({required this.registrarUrl, required this.apiKey}) {
    var innerClient = HttpClient();
    innerClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    _http = IOClient();
  }

  Future<Response> registrarApiRequest(
    NoPortsActivateApiEndpoints endpoint,
    Map<String, String?> data,
  ) async {
    Uri url = Uri.https(registrarUrl, endpoint.path);

    return _http.post(
      url,
      body: jsonEncode(data),
      headers: <String, String>{
        'Authorization': apiKey,
        'Content-Type': 'application/json',
      },
    );
  }

  Future<({String? cramkey, String? errorMessage})> verifyActivation({
    required String atsign,
    required String otp,
  }) async {
    var res = await registrarApiRequest(NoPortsActivateApiEndpoints.validate, {
      'atsign': atsign,
      'otp': otp,
    });
    if (res.statusCode != 200) {
      return (
        errorMessage:
            AtOnboardingLocalizations.current.error_server_unavailable,
        cramkey: null,
      );
    }
    var payload = jsonDecode(res.body);
    if (payload["message"] != "Verified") {
      // The toString is for typesafety & to prevent unexpected crashes
      return (errorMessage: payload["message"].toString(), cramkey: null);
    }
    String cramkey = payload["cramkey"]?.split(':').last ?? '';
    return (cramkey: cramkey, errorMessage: null);
  }

  Future<AtOnboardingResult> onboardFromCramKey({
    required String atsign,
    required String cramkey,
    required AtOnboardingConfig config,
  }) async {
    try {
      atsign = atsign.startsWith('@') ? atsign : '@$atsign';
      OnboardingService onboardingService = OnboardingService.getInstance();
      bool isExist = await onboardingService.isExistingAtsign(atsign);
      if (isExist) {
        return AtOnboardingResult.error(
          message: AtOnboardingLocalizations.current.error_atSign_activated,
        );
      }

      //Delay for waiting for ServerStatus change to teapot when activating an atsign
      await Future.delayed(const Duration(seconds: 10));

      config.atClientPreference.cramSecret = cramkey;
      onboardingService.setAtClientPreference = config.atClientPreference;

      onboardingService.setAtsign = atsign;
      var res = await onboardingService.onboard(
        atsign: atsign,
        cramkey: cramkey,
      );

      if (res.status == AtOnboardingResponseStatus.authSuccess) {
        int round = 1;
        const maxRounds = 20; // Increased from 10 to 20 (60 seconds total)
        AtStatus? atSignStatus = await onboardingService
            .checkAtSignServerStatus(atsign);

        while (atSignStatus?.status() != AtSignStatus.activated) {
          if (round > maxRounds) {
            // If authentication succeeded but activation is taking too long,
            // still return success since the auth step worked
            return AtOnboardingResult.success(atsign: atsign);
          }
          await Future.delayed(const Duration(seconds: 3));
          round++;
          atSignStatus = await onboardingService.checkAtSignServerStatus(
            atsign,
          );
        }

        if (atSignStatus?.status() == AtSignStatus.teapot) {
          return AtOnboardingResult.error(message: 'Server unreachable');
        } else if (atSignStatus?.status() == AtSignStatus.activated) {
          return AtOnboardingResult.success(atsign: atsign);
        }

        // Authentication succeeded, return success
        return AtOnboardingResult.success(atsign: atsign);
      }

      return AtOnboardingResult.error(message: 'Authentication failed');
    } catch (e) {
      return AtOnboardingResult.error(message: e.toString());
    }
  }
}
