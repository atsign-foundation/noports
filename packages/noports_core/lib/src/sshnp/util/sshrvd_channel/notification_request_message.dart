import 'dart:convert';

class SocketRendezvousRequestMessage {
  late String sessionId;
  late String atSignA;
  late String atSignB;
  late bool authenticateSocketA;
  late bool authenticateSocketB;
  late String clientNonce;

  @override
  String toString() {
    Map m = {};
    m['sessionId'] = sessionId;
    m['atSignA'] = atSignA;
    m['atSignB'] = atSignB;
    m['authenticateSocketA'] = authenticateSocketA;
    m['authenticateSocketB'] = authenticateSocketB;
    m['clientNonce'] = clientNonce;
    return jsonEncode(m);
  }
}
