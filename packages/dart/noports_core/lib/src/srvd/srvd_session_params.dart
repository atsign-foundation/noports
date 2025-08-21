import 'package:noports_core/sshnp_foundation.dart';

class SrvdSessionParams {
  final String sessionId;
  final String? atSignA;
  final String? atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String? publicKeyA;
  final String? publicKeyB;
  final String? clientNonce;
  final String? rvdNonce;
  final RelayAuthMode relayAuthMode;
  final String? relayAuthAesKey;
  final bool only443;
  final bool multipleAcksOk;
  final List<String> preFetch;

  SrvdSessionParams({
    required this.sessionId,
    required this.atSignA,
    this.atSignB,
    this.authenticateSocketA = false,
    this.authenticateSocketB = false,
    this.publicKeyA,
    this.publicKeyB,
    this.rvdNonce,
    this.clientNonce,
    this.relayAuthMode = RelayAuthMode.payload,
    this.relayAuthAesKey,
    required this.only443,
    required this.multipleAcksOk,
    required this.preFetch,
  });

  @override
  String toString() => toJson().toString();

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'atSignA': atSignA,
    'atSignB': atSignB,
    'authenticateSocketA': authenticateSocketA,
    'authenticateSocketB': authenticateSocketB,
    'publicKeyA': publicKeyA,
    'publicKeyB': publicKeyB,
    'rvdNonce': rvdNonce,
    'clientNonce': clientNonce,
    'relayAuthMode': relayAuthMode.name,
    'relayAuthAesKey': relayAuthAesKey,
    'only443': only443,
    'multipleAcksOk': multipleAcksOk,
    'preFetch': preFetch,
  };
}
