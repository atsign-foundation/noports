class SshnpSessionRequest {
  final bool direct;
  final String sessionId;
  final String host;
  final int port;
  final bool authenticateToRvd;
  final String clientNonce;
  final String? rvdNonce;
  final bool encryptRvdTraffic;
  final String? clientEphemeralPK;
  final String? clientEphemeralPKType;

  SshnpSessionRequest({
    required this.direct,
    required this.sessionId,
    required this.host,
    required this.port,
    required this.authenticateToRvd,
    required this.clientNonce,
    required this.rvdNonce,
    required this.encryptRvdTraffic,
    required this.clientEphemeralPK,
    required this.clientEphemeralPKType,
  });

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
      };
}
