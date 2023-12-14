import 'dart:convert';

class NotificationRequestMessage {
  @override
  String toString();
}

class SessionIdMessage extends NotificationRequestMessage{
  String sessionId;

  SessionIdMessage(this.sessionId);

  @override
  String toString() {
    return sessionId;
  }
}

class AuthentionEnablingMessage extends SessionIdMessage{
  String atSignA;
  String atSignB;
  bool authenticateSocketA;
  bool authenticateSocketB;

  AuthentionEnablingMessage(String sessionId, this.atSignA, this.atSignB, this.authenticateSocketA, this.authenticateSocketB) : super(sessionId);

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
