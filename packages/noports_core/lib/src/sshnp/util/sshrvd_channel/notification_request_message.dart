import 'dart:convert';

abstract class SrSessionRequest {
  late String sessionId;

  @override
  String toString();
}

class SessionIdMessage extends SrSessionRequest{

  @override
  String toString() {
    return sessionId;
  }
}

class AuthenticationEnablingMessage extends SessionIdMessage {
  late String atSignA;
  late String atSignB;
  late bool authenticateSocketA;
  late bool authenticateSocketB;

  @override
  String toString() {
    Map m = {};
    m['session'] = sessionId;
    m['atSignA'] = atSignA;
    m['atSignB'] = atSignB;
    m['authenticateSocketA'] = authenticateSocketA;
    m['authenticateSocketB'] = authenticateSocketB;
    return jsonEncode(m);
  }
}
