import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:noports_core/npa.dart'
    show NPAAuthCheckRequest, NPAAuthCheckResponse;
import 'package:npt_flutter/features/policy_logs/services/policy_log_monitor_service.dart';

/// A policy log notification as the policy service sends it: the RPC request
/// it answered, and a response carrying [responsePayload].
AtNotification _policyRequest(Map<String, dynamic> responsePayload) {
  final request = AtRpcReq(
    reqId: 1,
    payload: NPAAuthCheckRequest(
      daemonAtsign: '@lab',
      daemonDeviceName: 'lab01',
      daemonDeviceGroupName: '',
      clientAtsign: '@alice',
    ).toJson(),
  );
  final response = AtRpcResp(
    reqId: 1,
    respType: AtRpcRespType.success,
    payload: responsePayload,
  );
  return AtNotification.empty()
    ..from = '@policy'
    ..to = '@admin'
    ..key = '@admin:req1.logs.policy.sshnp@policy'
    ..value = jsonEncode({
      'daemon': '@lab',
      'timestamp': 0,
      'payload': {'request': request, 'response': response},
    });
}

Map<String, dynamic> _denial(String? message) => NPAAuthCheckResponse(
  authorized: false,
  message: message,
  permitOpen: [],
).toJson();

void main() {
  group('PolicyLogEntry.fromNotification', () {
    test('a denial carries the policy service\'s reason', () {
      final entry = PolicyLogEntry.fromNotification(
        _policyRequest(_denial('outside hours')),
      );
      expect(entry.type, 'policy request');
      expect(
        entry.allowedServices,
        'Request: @alice → @lab (DENIED: outside hours)',
      );
    });

    final noReason = <String, Map<String, dynamic>>{
      'absent': _denial(null)..remove('message'),
      'null': _denial(null),
      'empty': _denial(''),
      'whitespace': _denial('   '),
      'not a string': _denial(null)..['message'] = 42,
    };
    noReason.forEach((shape, payload) {
      test('a denial whose message is $shape shows no reason', () {
        expect(
          PolicyLogEntry.fromNotification(
            _policyRequest(payload),
          ).allowedServices,
          'Request: @alice → @lab (DENIED)',
        );
      });
    });

    test('a denial reason is shown trimmed', () {
      expect(
        PolicyLogEntry.fromNotification(
          _policyRequest(_denial('  outside hours\n')),
        ).allowedServices,
        'Request: @alice → @lab (DENIED: outside hours)',
      );
    });

    test('an authorized request lists what it permits', () {
      final entry = PolicyLogEntry.fromNotification(
        _policyRequest(
          NPAAuthCheckResponse(
            authorized: true,
            message: 'ok',
            permitOpen: ['localhost:22'],
          ).toJson(),
        ),
      );
      expect(
        entry.allowedServices,
        'Request: @alice → @lab (AUTHORIZED - Permit: localhost:22)',
      );
    });
  });
}
