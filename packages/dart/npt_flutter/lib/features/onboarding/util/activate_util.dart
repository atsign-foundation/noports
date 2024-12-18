import 'dart:convert';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart' hide Response;
import 'package:at_onboarding_flutter/at_onboarding_services.dart';
// ignore: implementation_imports
import 'package:at_onboarding_flutter/src/utils/at_onboarding_response_status.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';

// Type returned from a method below
export 'package:at_onboarding_flutter/src/utils/at_onboarding_response_status.dart';

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
    innerClient.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
    _http = IOClient();
  }

  Future<Response> registrarApiRequest(NoPortsActivateApiEndpoints endpoint, Map<String, String?> data) async {
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

  Future<({String? cramkey, String? errorMessage})> verifyActivation(
      {required String atsign, required String otp}) async {
    var res = await registrarApiRequest(
      NoPortsActivateApiEndpoints.validate,
      {
        'atsign': atsign,
        'otp': otp,
      },
    );
    if (res.statusCode != 200) {
      return (
        errorMessage: AtOnboardingLocalizations.current.error_server_unavailable,
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
      AtOnboardingRequest req = AtOnboardingRequest(atsign);
      var res = await onboardingService.onboard(
        cramSecret: cramkey,
        atOnboardingRequest: req,
      );

      if (res) {
        int round = 1;
        ServerStatus? atSignStatus = await onboardingService.checkAtSignServerStatus(atsign);
        while (atSignStatus != ServerStatus.activated) {
          if (round > 10) {
            break;
          }
          await Future.delayed(const Duration(seconds: 3));
          round++;
          atSignStatus = await onboardingService.checkAtSignServerStatus(atsign);
        }

        if (atSignStatus == ServerStatus.teapot) {
          return AtOnboardingResult.error(
            message: AtOnboardingLocalizations.current.msg_atSign_unreachable,
          );
        } else if (atSignStatus == ServerStatus.activated) {
          return AtOnboardingResult.success(atsign: atsign);
        }
      }

      return AtOnboardingResult.error(message: AtOnboardingLocalizations.current.error_authenticated_failed);
    } catch (e) {
      if (e == AtOnboardingResponseStatus.authFailed) {
        return AtOnboardingResult.error(
          message: AtOnboardingLocalizations.current.error_authenticated_failed,
        );
      } else if (e == AtOnboardingResponseStatus.serverNotReached) {
        return AtOnboardingResult.error(
          message: AtOnboardingLocalizations.current.msg_atSign_unreachable,
        );
      } else if (e == AtOnboardingResponseStatus.timeOut) {
        return AtOnboardingResult.error(
          message: AtOnboardingLocalizations.current.msg_response_time_out,
        );
      }
      return AtOnboardingResult.error(message: e.toString());
    }
  }
}
