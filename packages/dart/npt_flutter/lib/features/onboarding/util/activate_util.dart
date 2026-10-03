import 'dart:convert';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/at_client_methods.dart';

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
    _http = IOClient(innerClient);
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
  }) async {
    var res = await registrarApiRequest(NoPortsActivateApiEndpoints.validate, {
      'atsign': atsign,
      'otp': otp,
    });
    if (res.statusCode != 200) {
      String errorMessage;
      try {
        final Map<String, dynamic> payload = jsonDecode(res.body);
        errorMessage = payload["message"]?.toString() ?? res.body;
      } catch (_) {
        errorMessage = res.body;
      }
      return (errorMessage: errorMessage, cramkey: null);
    }
    var payload = jsonDecode(res.body);
    if (payload["message"] != "Verified") {
      // The toString is for typesafety & to prevent unexpected crashes
      return (errorMessage: payload["message"].toString(), cramkey: null);
    }
    String cramkey = payload["cramkey"]?.split(':').last ?? '';
    return (cramkey: cramkey, errorMessage: null);
  }

  /// Activates an atsign from teapot using a CRAM key obtained via
  /// [verifyActivation], writes its keys to the keychain and adopts the
  /// client the activation opens.
  Future<NoPortsOnboardingResult> onboardFromCramKey({
    required Atsign atsign,
    required String cramkey,
    required String rootDomain,
    required AppLocalizations strings,
  }) async {
    try {
      await AtClientMethods.stopCurrentClient();
      final client = await atsign.activate(
        cramSecret: cramkey,
        keys: KeychainAtKeysIo(),
        preference: await AtClientMethods.loadAtClientPreference(rootDomain),
      );
      AtClientMethods.adopt(client);
      return NoPortsOnboardingResult.success(atsign: atsign);
    } on AtTimeoutException {
      return NoPortsOnboardingResult.error(message: strings.msgResponseTimeOut);
    } catch (e) {
      App.log('Failed to onboard $atsign from cram key: $e'.loggable);
      return NoPortsOnboardingResult.error(
        message: describeOnboardingError(e, strings),
      );
    }
  }
}
