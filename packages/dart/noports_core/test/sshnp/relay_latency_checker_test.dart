import 'dart:io';

import 'package:noports_core/src/common/relay_latency_checker.dart';
import 'package:test/test.dart';

void main() {
  group('RelayLatencyChecker.measureLatencies', () {
    test('empty rvServers returns empty map', () async {
      final result = await RelayLatencyChecker.measureLatencies({});
      expect(result, isEmpty);
    });

    test('missing ipaddr → -1', () async {
      final result = await RelayLatencyChecker.measureLatencies({
        '@rv_am': {'port': 443},
      });
      expect(result['@rv_am'], -1);
    });

    test('missing port → -1', () async {
      final result = await RelayLatencyChecker.measureLatencies({
        '@rv_am': {'ipaddr': '1.2.3.4'},
      });
      expect(result['@rv_am'], -1);
    });

    test('both ipaddr and port missing → -1', () async {
      final result = await RelayLatencyChecker.measureLatencies({
        '@rv_am': <String, dynamic>{},
      });
      expect(result['@rv_am'], -1);
    });

    test('unreachable host → -1', () async {
      // 192.0.2.x is TEST-NET-1 (RFC 5737) — guaranteed not routable
      final result = await RelayLatencyChecker.measureLatencies(
        {'@rv_am': {'ipaddr': '192.0.2.1', 'port': 9}},
        timeout: const Duration(milliseconds: 200),
      );
      expect(result['@rv_am'], -1);
    });

    test('reachable host → latency ≥ 0', () async {
      final listener = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(() async {
        await listener.close();
      });

      final result = await RelayLatencyChecker.measureLatencies({
        '@rv_am': {'ipaddr': '127.0.0.1', 'port': listener.port},
      });
      expect(result['@rv_am'], greaterThanOrEqualTo(0));
    });

    test('mixed reachable and unreachable hosts', () async {
      final listener = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(() async {
        await listener.close();
      });

      final result = await RelayLatencyChecker.measureLatencies(
        {
          '@rv_am': {'ipaddr': '127.0.0.1', 'port': listener.port},
          '@rv_eu': {'ipaddr': '192.0.2.1', 'port': 9}, // TEST-NET-1
        },
        timeout: const Duration(milliseconds: 200),
      );
      expect(result.keys, containsAll(['@rv_am', '@rv_eu']));
      expect(result['@rv_am'], greaterThanOrEqualTo(0));
      expect(result['@rv_eu'], -1);
    });

    test('all keys present in result regardless of outcome', () async {
      final result = await RelayLatencyChecker.measureLatencies(
        {
          '@rv_am': {'port': 443}, // missing ipaddr → -1
          '@rv_eu': {'ipaddr': '192.0.2.2', 'port': 9}, // unreachable → -1
        },
        timeout: const Duration(milliseconds: 200),
      );
      expect(result.keys, containsAll(['@rv_am', '@rv_eu']));
      expect(result['@rv_am'], -1);
      expect(result['@rv_eu'], -1);
    });
  });
}
