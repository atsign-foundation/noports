import 'dart:convert';

abstract class SSHNPDNotificationRequestMessage {
  late String sessionId;

  @override
  String toString();
}

class SessionIdMessage extends SSHNPDNotificationRequestMessage{

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

class SSHNPDNotificationRequestMessageManager {
  static SSHNPDNotificationRequestMessage get(bool authenticate) {

    if(authenticate) {
      return AuthenticationEnablingMessage();
    }
    return SessionIdMessage();
  }
}
