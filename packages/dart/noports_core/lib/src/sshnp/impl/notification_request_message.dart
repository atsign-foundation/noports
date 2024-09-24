import 'package:noports_core/utils.dart';

class SshnpSessionRequest {
  final bool direct;
  final String sessionId;
  final String host;
  final int port;
  final bool? authenticateToRvd;
  final String? clientNonce;
  final String? rvdNonce;
  final bool? encryptRvdTraffic;
  final String? clientEphemeralPK;
  final String? clientEphemeralPKType;
  final String? username;
  final int? remoteForwardPort;
  final String? privateKey;

  SshnpSessionRequest({
    required this.direct,
    required this.sessionId,
    required this.host,
    required this.port,
    // optional params
    this.authenticateToRvd,
    this.clientNonce,
    this.rvdNonce,
    this.encryptRvdTraffic,
    this.clientEphemeralPK,
    this.clientEphemeralPKType,
    // required for reverse (direct = false)
    this.username,
    this.remoteForwardPort,
    this.privateKey,
  }) {
    // Assertations originally from Sshnpd
    // sessionId, host (of the rvd) and port (of the rvd) are required.
    assertValidValue('sessionId', sessionId, String);
    assertValidValue('host', host, String);
    assertValidValue('port', port, int);

    // v5+ params are not required but must be valid if supplied
    assertNullOrValidValue('authenticateToRvd', authenticateToRvd, bool);
    assertNullOrValidValue('clientNonce', clientNonce, String);
    assertNullOrValidValue('rvdNonce', rvdNonce, String);
    assertNullOrValidValue('encryptRvdTraffic', encryptRvdTraffic, bool);
    assertNullOrValidValue('clientEphemeralPK', clientEphemeralPK, String);
    assertNullOrValidValue(
        'clientEphemeralPKType', clientEphemeralPKType, String);

    // If a reverse ssh (v3, LEGACY BEHAVIOUR) is being requested, then we
    // also require a username (to ssh back to the client), a privateKey (for
    // that ssh) and a remoteForwardPort, to set up the ssh tunnel back to
    // this device from the client side.
    if (!direct) {
      assertValidValue('username', username, String);
      assertValidValue('remoteForwardPort', remoteForwardPort, int);
      assertValidValue('privateKey', privateKey, String);
    }
  }

  static SshnpSessionRequest fromJson(Map<String, dynamic> json) {
    return SshnpSessionRequest(
      direct: json['direct'],
      sessionId: json['sessionId'],
      host: json['host'],
      port: json['port'],
      authenticateToRvd: json['authenticateToRvd'],
      clientNonce: json['clientNonce'],
      rvdNonce: json['rvdNonce'],
      encryptRvdTraffic: json['encryptRvdTraffic'],
      clientEphemeralPK: json['clientEphemeralPK'],
      clientEphemeralPKType: json['clientEphemeralPKType'],
    );
  }

  /// NB: Do not change any existing names as this will break all previous daemons
  Map<String, dynamic> toJson() => {
        'direct': direct,
        'sessionId': sessionId,
        'host': host,
        'port': port,
        'authenticateToRvd': authenticateToRvd,
        'clientNonce': clientNonce,
        'rvdNonce': rvdNonce,
        'encryptRvdTraffic': encryptRvdTraffic,
        'clientEphemeralPK': clientEphemeralPK,
        'clientEphemeralPKType': clientEphemeralPKType,
      };
}

class NptSessionRequest {
  static const int defaultTimeout = 1000 * 60;
  final String sessionId;
  final String rvdHost;
  final int rvdPort;
  final String requestedHost;
  final int requestedPort;
  final bool authenticateToRvd;
  final String clientNonce;
  final String rvdNonce;
  final bool encryptRvdTraffic;
  final String clientEphemeralPK;
  final String clientEphemeralPKType;
  final Duration timeout;

  NptSessionRequest({
    required this.sessionId,
    required this.rvdHost,
    required this.rvdPort,
    required this.requestedHost,
    required this.requestedPort,
    required this.authenticateToRvd,
    required this.clientNonce,
    required this.rvdNonce,
    required this.encryptRvdTraffic,
    required this.clientEphemeralPK,
    required this.clientEphemeralPKType,
    required this.timeout,
  });

  static NptSessionRequest fromJson(Map<String, dynamic> json) {
    return NptSessionRequest(
      sessionId: json['sessionId'],
      rvdHost: json['rvdHost'],
      rvdPort: json['rvdPort'],
      requestedHost: json['requestedHost'],
      requestedPort: json['requestedPort'],
      authenticateToRvd: json['authenticateToRvd'],
      clientNonce: json['clientNonce'],
      rvdNonce: json['rvdNonce'],
      encryptRvdTraffic: json['encryptRvdTraffic'],
      clientEphemeralPK: json['clientEphemeralPK'],
      clientEphemeralPKType: json['clientEphemeralPKType'],
      timeout: Duration(milliseconds: json['timeout'] ?? defaultTimeout),
    );
  }

  /// NB: Do not change any existing names as this will break all previous daemons
  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'rvdHost': rvdHost,
        'rvdPort': rvdPort,
        'requestedPort': requestedPort,
        'requestedHost': requestedHost,
        'authenticateToRvd': authenticateToRvd,
        'clientNonce': clientNonce,
        'rvdNonce': rvdNonce,
        'encryptRvdTraffic': encryptRvdTraffic,
        'clientEphemeralPK': clientEphemeralPK,
        'clientEphemeralPKType': clientEphemeralPKType,
        'timeout': timeout.inMilliseconds,
      };
}
