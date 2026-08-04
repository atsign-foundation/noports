import 'dart:convert';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:at_server_status/at_server_status.dart';
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/at_client_activation.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

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
    required Atsign atsign,
    required String otp,
    required AppLocalizations strings,
  }) async {
    var res = await registrarApiRequest(NoPortsActivateApiEndpoints.validate, {
      'atsign': atsign,
      'otp': otp,
    });
    if (res.statusCode != 200) {
      return (errorMessage: strings.errorAtServerUnavailable, cramkey: null);
    }
    var payload = jsonDecode(res.body);
    if (payload["message"] != "Verified") {
      // The toString is for typesafety & to prevent unexpected crashes
      return (errorMessage: payload["message"].toString(), cramkey: null);
    }
    String cramkey = payload["cramkey"]?.split(':').last ?? '';
    return (cramkey: cramkey, errorMessage: null);
  }

  Future<NoPortsOnboardingResult> onboardFromCramKey({
    required Atsign atsign,
    required String cramkey,
    required AtClientPreference atClientPreference,
    required AppLocalizations strings,
  }) async {
    try {
      final List<String> existing = await KeychainStorage().getAllAtsigns();
      if (existing.contains(atsign)) {
        return NoPortsOnboardingResult.error(
          message: strings.errorAtsignAlreadyActivated,
        );
      }

      //Delay for waiting for ServerStatus change to teapot when activating an atsign
      await Future.delayed(const Duration(seconds: 10));

      atClientPreference.cramSecret = cramkey;

      final AtOnboardingRequest req = AtOnboardingRequest(
        atsign,
        rootDomain: AtRootDomain(atClientPreference.rootDomain, 64),
        atKeysIo: KeychainAtKeysIo(),
      );
      final AtOnboardingResponse res = await AuthService().onboard(
        req,
        cramkey,
      );

      if (res.isSuccessful) {
        final AtServerStatus serverStatus = AtStatusImpl(
          rootUrl: atClientPreference.rootDomain,
          rootPort: atClientPreference.rootPort,
        );

        int round = 1;
        AtStatus atsignStatus = await serverStatus.get(atsign);
        while (atsignStatus.status() != AtSignStatus.activated) {
          if (round > 10) {
            break;
          }
          await Future.delayed(const Duration(seconds: 3));
          round++;
          atsignStatus = await serverStatus.get(atsign);
        }

        if (atsignStatus.status() == AtSignStatus.teapot) {
          return NoPortsOnboardingResult.error(
            message: strings.errorAtServerUnreachable,
          );
        } else if (atsignStatus.status() == AtSignStatus.activated) {
          await activateAtClientFromAuthResponse(
            atsign: atsign,
            atClientPreference: atClientPreference,
            response: res,
          );
          return NoPortsOnboardingResult.success(atsign: atsign);
        }
      }

      return NoPortsOnboardingResult.error(
        message: strings.errorAuthenticatinFailed,
      );
    } on AtTimeoutException {
      return NoPortsOnboardingResult.error(
        message: strings.errorAuthenticationTimedOut,
      );
    } on UnAuthenticatedException {
      return NoPortsOnboardingResult.error(
        message: strings.errorAuthenticatinFailed,
      );
    } on AtConnectException {
      return NoPortsOnboardingResult.error(
        message: strings.errorAtServerUnreachable,
      );
    } catch (e) {
      return NoPortsOnboardingResult.error(message: e.toString());
    }
  }
}
