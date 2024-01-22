import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

void main() {
  test('test notification subscription regex', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'test.${Srvd.namespace}';
  });

  test('srvd should accept notification in new request_ports format', () {
    // Create a notification in rvd namespace
    AtNotification notification = AtNotification.empty();
    notification.key = 'request_ports.test.${Srvd.namespace}';
    expect(SrvdUtil(MockAtClient()).accept(notification), true);
  });

  test(
      'srvd backwards compatibility test - should handle both legacy and new messages in JSON format',
      () async {
    Map m = {};
    m['session'] = 'hello';
    m['atSignA'] = '@4314sagittarius';
    m['atSignB'] = '@4314sagittarius';
    m['authenticateSocketA'] = false;
    m['authenticateSocketB'] = false;

    // New message
    AtNotification notification = AtNotification.empty();
    notification.key = 'request_ports.test.${Srvd.namespace}';
    notification.value = jsonEncode(m);

    expect(SrvdUtil(MockAtClient()).accept(notification), true);
  });
}
