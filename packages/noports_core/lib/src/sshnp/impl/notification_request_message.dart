import 'dart:convert';

abstract class SSHNPNotificationRequestMessage {
  late bool direct;
  late String sessionId;
  late String host;
  late int port;

  Map message();
}
class SessionIdMessage extends SSHNPNotificationRequestMessage{

  @override
  Map message() {
    Map m = {};
    m['direct'] = true;
    m['sessionId'] = sessionId;
    m['host'] = host;
    m['port'] = port;

    return m;
  }
}

class AuthenticationEnablingMessage extends SessionIdMessage{
  bool authenticate = false;

  @override
  Map message() {
    Map m = super.message();
    m['authenticate'] = authenticate;
    return m;
  }
}

class SSHNPNotificationRequestMessageManager {
  static SSHNPNotificationRequestMessage get(bool authenticate) {

    if(authenticate) {
        return AuthenticationEnablingMessage()..authenticate = true;
    }
    return SessionIdMessage();
  }
}