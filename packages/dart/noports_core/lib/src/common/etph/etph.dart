import 'dart:convert';

import 'package:at_commons/atsign.dart';
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:http/http.dart' as http;

/// Takes Error Telemetry and "phones home" so operators of NoPorts and
/// atPlatform infrastructure have visibility into problems that are being
/// encountered by NoPorts client programs.
///
/// Implementations should not use atPlatform to "phone home" since this would
/// not cover situations where the programs cannot use the platform, for
/// example because their local network environment is not allowing
/// connectivity, or because the atDirectory and/or atServers are currently
/// suffering an outage.
abstract interface class ETPH {
  factory ETPH.http(Atsign atSign, String url) {
    return _ETPhoneHomeHttp(atSign, url);
  }

  /// The atSign being used by the client program
  Atsign get atSign;

  /// The payload to send
  Future<bool> phoneHome(Map<String, dynamic> json);
}

class _ETPhoneHomeHttp implements ETPH {
  @override
  final Atsign atSign;

  final String url;

  late final Uri uri;

  late final AtSignLogger logger;

  _ETPhoneHomeHttp(this.atSign, this.url) {
    uri = Uri.parse('$url/${base64Encode(atSign.codeUnits)}');
    logger = AtSignLogger(runtimeType.toString())..level = 'info';
  }

  @override
  Future<bool> phoneHome(Map<String, dynamic> json) async {
    try {
      String body = jsonEncode(json);
      logger.info('Phoning home: $body');
      var response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: body,
      );
      logger.info('Response status: ${response.statusCode}');
      logger.info('Response body: ${response.body}');

      return (response.statusCode >= 200 && response.statusCode < 300);
    } catch (e) {
      logger.severe('Failed to phoneHome: $e');
      return false;
    }
  }
}
