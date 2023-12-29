class SshnpSessionRequest {
  final bool direct;
  final String sessionId;
  final String host;
  final int port;
  final bool authenticateToRvd;
  final String clientNonce;
  final String rvdNonce;

  SshnpSessionRequest({
    required this.direct,
    required this.sessionId,
    required this.host,
    required this.port,
    required this.authenticateToRvd,
    required this.clientNonce,
    required this.rvdNonce,
  });

  Map<String, dynamic> toJson() => {
        'direct': direct,
        'sessionId': sessionId,
        'host': host,
        'port': port,
        'authenticateToRvd': authenticateToRvd,
        'clientNonce': clientNonce,
        'rvdNonce': rvdNonce,
      };
}
