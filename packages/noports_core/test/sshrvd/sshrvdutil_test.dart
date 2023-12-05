import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshrvd/sshrvd_impl.dart';
import 'package:noports_core/sshrvd.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:test/test.dart';

void main() {
  test('test notification subscription regex', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'test.${Sshrvd.namespace}';

  });

  test('sshrvd should accept notification in new request_ports format', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'request_ports.test.${Sshrvd.namespace}';
    expect(SshrvdUtil.accept(notification), true);
  });

  test('sshrvd backwards compatibility test - should handle both legacy and new messages in JSON format', () async {
    Map m = {};
    m['session'] = 'hello';
    m['atSignA'] = '@4314sagittarius';
    m['atSignB'] = '@4314sagittarius';
    m['authenticateSocketA'] = false;
    m['authenticateSocketB'] = false;

    // New message
    AtNotification notification = AtNotification.empty();
    notification.key = 'request_ports.test.${Sshrvd.namespace}';
    notification.value = jsonEncode(m);

    expect(SshrvdUtil.accept(notification), true);

    late String session;
    late String atSignA;
    String? atSignB;
    SocketAuthenticator? socketAuthenticatorA;
    SocketAuthenticator? socketAuthenticatorB;
    (session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB) = await SshrvdUtil.getParams(notification);
    expect(session, 'hello');
    expect(atSignA, '@4314sagittarius');
    expect(atSignB, '@4314sagittarius');
    expect(socketAuthenticatorA, null);
    expect(socketAuthenticatorB, null);

    // Legacy message, but a JSON
    notification = AtNotification.empty();
    notification.key = 'test.${Sshrvd.namespace}';
    notification.value = jsonEncode(m);
    notification.from = '@4314sagittarius';

    expect(SshrvdUtil.accept(notification), true);
    (session, atSignA, atSignB, socketAuthenticatorA, socketAuthenticatorB) = await SshrvdUtil.getParams(notification);
    expect(atSignA, '@4314sagittarius');
    expect(atSignB, null);
    expect(socketAuthenticatorA, null);
    expect(socketAuthenticatorB, null);
  });
}
