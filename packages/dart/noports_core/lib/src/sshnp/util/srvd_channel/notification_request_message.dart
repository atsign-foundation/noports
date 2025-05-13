import 'dart:convert';

import 'package:noports_core/sshnp_foundation.dart';

class SocketRendezvousRequestMessage {
  final String sessionId;
  final String atSignA;
  final String atSignB;
  final bool authenticateSocketA;
  final bool authenticateSocketB;
  final String clientNonce;
  final RelayAuthMode relayAuthMode;
  final String? relayAuthAesKey;

  SocketRendezvousRequestMessage({
    required this.sessionId,
    required this.atSignA,
    required this.atSignB,
    required this.authenticateSocketA,
    required this.authenticateSocketB,
    required this.clientNonce,
    required this.relayAuthMode,
    required this.relayAuthAesKey,
  });

  @override
  String toString() {
    Map m = {};
    m['sessionId'] = sessionId;
    m['atSignA'] = atSignA;
    m['atSignB'] = atSignB;
    m['authenticateSocketA'] = authenticateSocketA;
    m['authenticateSocketB'] = authenticateSocketB;
    m['clientNonce'] = clientNonce;
    m['relayAuthMode'] = relayAuthMode.name;
    m['relayAuthAesKey'] = relayAuthAesKey;
    return jsonEncode(m);
  }
}
