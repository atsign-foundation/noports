abstract class SshnpSessionRequest {
  late bool direct;
  late String sessionId;
  late String host;
  late int port;

  Map message();
}

class SessionIdMessage extends SshnpSessionRequest{

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
  bool authenticate = true;

  @override
  Map message() {
    Map m = super.message();
    m['authenticate'] = authenticate;
    return m;
  }
}