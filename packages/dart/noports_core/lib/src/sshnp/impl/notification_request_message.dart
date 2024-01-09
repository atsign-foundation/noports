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
