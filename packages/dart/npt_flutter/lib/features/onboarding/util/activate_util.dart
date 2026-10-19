import 'dart:convert';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:flutter/foundation.dart' show kDebugMode, visibleForTesting;
import 'package:http/http.dart';
import 'package:http/io_client.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/at_client_methods.dart';

const apiBase = '/api/app/v3';

/// Whether [ActivateUtil] skips verifying the registrar's TLS certificate, for
/// local testing against a registrar whose certificate the device doesn't
/// trust.
///
/// Set with `--dart-define=NPT_DISABLE_REGISTRAR_TLS_VERIFICATION=true`. It
/// takes effect only where [kDebugMode] is true, so release builds always
/// verify.
const disableRegistrarTlsVerification =
    kDebugMode &&
    bool.fromEnvironment('NPT_DISABLE_REGISTRAR_TLS_VERIFICATION');

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
    _http = IOClient(
      disableRegistrarTlsVerification
          ? (HttpClient()..badCertificateCallback = (cert, host, port) => true)
          : null,
    );
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
      final client = await activate(atsign, cramkey, rootDomain);
      AtClientMethods.adopt(client);
      return NoPortsOnboardingResult.success(atsign: atsign);
    } on AtTimeoutException {
      return NoPortsOnboardingResult.error(message: strings.msgResponseTimeOut);
    } catch (e) {
      App.log(
        'Failed to onboard $atsign from cram key: ${e.runtimeType}'.loggable,
      );
      return NoPortsOnboardingResult.error(
        message: describeOnboardingError(e, strings),
      );
    }
  }

  /// Activates [atsign] with [cramkey] against [rootDomain], writing its keys
  /// to the keychain, and returns the client the activation opens.
  @visibleForTesting
  Future<AtClient> Function(Atsign atsign, String cramkey, String rootDomain)
  activate = _activateIntoKeychain;

  static Future<AtClient> _activateIntoKeychain(
    Atsign atsign,
    String cramkey,
    String rootDomain,
  ) async => atsign.activate(
    cramSecret: cramkey,
    keys: KeychainAtKeysIo(),
    preference: await AtClientMethods.loadAtClientPreference(rootDomain),
  );
}
