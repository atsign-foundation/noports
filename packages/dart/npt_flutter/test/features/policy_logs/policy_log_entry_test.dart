import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/features/policy_logs/services/policy_log_monitor_service.dart';

AtNotification _policyRequest(Map<String, dynamic> responsePayload) =>
    AtNotification.empty()
      ..from = '@policy'
      ..to = '@admin'
      ..key = '@admin:req1.logs.policy.sshnp@policy'
      ..value = jsonEncode({
        'payload': {
          'request': {
            'payload': {
              'daemonDeviceName': 'lab01',
              'clientAtsign': '@alice',
              'daemonAtsign': '@lab',
            },
          },
          'response': {'payload': responsePayload},
        },
      });

void main() {
  group('PolicyLogEntry.fromNotification', () {
    test('a denial carries the policy service\'s reason', () {
      final entry = PolicyLogEntry.fromNotification(
        _policyRequest({'authorized': false, 'message': 'outside hours'}),
      );
      expect(entry.type, 'policy request');
      expect(
        entry.allowedServices,
        'Request: @alice → @lab (DENIED: outside hours)',
      );
    });

    final noReason = <String, Map<String, dynamic>>{
      'absent': {'authorized': false},
      'null': {'authorized': false, 'message': null},
      'empty': {'authorized': false, 'message': ''},
      'whitespace': {'authorized': false, 'message': '   '},
      'not a string': {'authorized': false, 'message': 42},
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
          _policyRequest({'authorized': false, 'message': '  outside hours\n'}),
        ).allowedServices,
        'Request: @alice → @lab (DENIED: outside hours)',
      );
    });

    test('an authorized request lists what it permits', () {
      final entry = PolicyLogEntry.fromNotification(
        _policyRequest({
          'authorized': true,
          'message': 'ok',
          'permitOpen': ['localhost:22'],
        }),
      );
      expect(
        entry.allowedServices,
        'Request: @alice → @lab (AUTHORIZED - Permit: localhost:22)',
      );
    });
  });
}
