import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/relay_selector.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

import 'sshnp_mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AtNotification _discoverResponse(
  String fromRv,
  String toClient,
  Map<String, dynamic> ipInfo,
) =>
    AtNotification(
      fromRv,
      'discover_response.${Srvd.namespace}$fromRv',
      fromRv,
      toClient,
      DateTime.now().millisecondsSinceEpoch,
      'update',
      false,
      value: jsonEncode(ipInfo),
      operation: 'update',
    );

AtNotification _latencyResponse(
  String fromDaemon,
  String toClient,
  String device,
  Map<String, int> latencies,
) =>
    AtNotification(
      fromDaemon,
      'relay_latency_response.$device.${DefaultArgs.namespace}',
      fromDaemon,
      toClient,
      DateTime.now().millisecondsSinceEpoch,
      'update',
      false,
      value: jsonEncode(latencies),
      operation: 'update',
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RelaySelector', () {
    late MockAtClient mockAtClient;
    late MockNotificationService mockNotificationService;
    late StreamController<AtNotification> streamCtrl;
    late RelaySelector rs;

    const clientAtSign = '@client';
    const sshnpdAtSign = '@daemon';
    const device = 'mydevice';
    const rootDomain = 'root.atsign.org';

    setUpAll(() {
      registerFallbackValue(AtKey());
      registerFallbackValue(const Duration(seconds: 10));
      registerFallbackValue(AtNotification.empty());
      registerFallbackValue(NotificationParams.forUpdate(AtKey()));
    });

    setUp(() {
      mockAtClient = MockAtClient();
      mockNotificationService = MockNotificationService();

      when(() => mockAtClient.getCurrentAtSign()).thenReturn(clientAtSign);
      when(
        () => mockAtClient.notificationService,
      ).thenReturn(mockNotificationService);

      streamCtrl = StreamController.broadcast();

      when(
        () => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((_) => streamCtrl.stream);

      // Default notify stub — does nothing; overridden per test as needed.
      when(
        () => mockNotificationService.notify(
          any(),
          checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSuccess: any(named: 'onSuccess'),
          onError: any(named: 'onError'),
        ),
      ).thenAnswer((_) async => NotificationResult());

      rs = RelaySelector(
        atClient: mockAtClient,
        clientAtSign: clientAtSign,
        sshnpdAtSign: sshnpdAtSign,
        device: device,
        rootDomain: rootDomain,
      );
    });

    tearDown(() => streamCtrl.close());

    // -----------------------------------------------------------------------
    // constructor
    // -----------------------------------------------------------------------
    group('constructor', () {
      test('builds rvServerListUrl from plain domain', () {
        expect(
          rs.rvServerListUrl,
          'https://atsign-foundation.github.io/noports/root.atsign.org/standard_relays.json',
        );
      });

      test('strips proxy: prefix from rootDomain', () {
        final withProxy = RelaySelector(
          atClient: mockAtClient,
          clientAtSign: clientAtSign,
          sshnpdAtSign: sshnpdAtSign,
          device: device,
          rootDomain: 'proxy:proxy0001.atsign.org',
        );
        expect(
          withProxy.rvServerListUrl,
          'https://atsign-foundation.github.io/noports/proxy0001.atsign.org/standard_relays.json',
        );
      });
    });

    // -----------------------------------------------------------------------
    // requestRelayIpAddress
    // -----------------------------------------------------------------------
    group('requestRelayIpAddress', () {
      const rv = '@rv_am';

      test('returns IP info from discover response', () async {
        final expected = {'ipaddr': '1.2.3.4', 'port': 443};
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          streamCtrl.add(_discoverResponse(rv, clientAtSign, expected));
          return NotificationResult();
        });

        final result = await rs.requestRelayIpAddress(rv.toAtsign());
        expect(result, expected);
      });

      test('throws TimeoutException when RV never responds', () {
        expect(
          () => rs.requestRelayIpAddress(
            rv.toAtsign(),
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('notification from wrong sender is ignored → timeout', () {
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          // from '@wrong', not rv → filtered by `notification.from == rvAtSign`
          streamCtrl.add(
            _discoverResponse('@wrong', clientAtSign, {'ipaddr': '9.9.9.9', 'port': 443}),
          );
          return NotificationResult();
        });

        expect(
          () => rs.requestRelayIpAddress(
            rv.toAtsign(),
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('notification with null value is ignored → timeout', () {
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          streamCtrl.add(
            AtNotification(
              rv,
              'discover_response.${Srvd.namespace}$rv',
              rv,
              clientAtSign,
              DateTime.now().millisecondsSinceEpoch,
              'update',
              false,
              value: null, // filtered by `notification.value != null`
              operation: 'update',
            ),
          );
          return NotificationResult();
        });

        expect(
          () => rs.requestRelayIpAddress(
            rv.toAtsign(),
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });
    });

    // -----------------------------------------------------------------------
    // fetchDeviceLatencies
    // -----------------------------------------------------------------------
    group('fetchDeviceLatencies', () {
      final rvServers = {
        '@rv_am': {'ipaddr': '1.2.3.4', 'port': 443},
        '@rv_eu': {'ipaddr': '1.2.3.5', 'port': 443},
      };

      test('returns latency map when device responds', () async {
        final expected = {'@rv_am': 42, '@rv_eu': 45};
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          streamCtrl.add(
            _latencyResponse(sshnpdAtSign, clientAtSign, device, expected),
          );
          return NotificationResult();
        });

        final result = await rs.fetchDeviceLatencies(rvServers);
        expect(result, expected);
      });

      test('throws TimeoutException when device never responds', () {
        expect(
          () => rs.fetchDeviceLatencies(
            rvServers,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('notification from wrong sender is ignored → timeout', () {
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          // from '@wrong', not sshnpdAtSign → filtered
          streamCtrl.add(
            _latencyResponse('@wrong', clientAtSign, device, {'@rv_am': 10}),
          );
          return NotificationResult();
        });

        expect(
          () => rs.fetchDeviceLatencies(
            rvServers,
            timeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });

      test('malformed JSON response throws FormatException', () async {
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          streamCtrl.add(
            AtNotification(
              sshnpdAtSign,
              'relay_latency_response.$device.${DefaultArgs.namespace}',
              sshnpdAtSign,
              clientAtSign,
              DateTime.now().millisecondsSinceEpoch,
              'update',
              false,
              value: 'not-valid-json{{{',
              operation: 'update',
            ),
          );
          return NotificationResult();
        });

        expect(
          () => rs.fetchDeviceLatencies(rvServers),
          throwsA(isA<FormatException>()),
        );
      });

      test('second notification after completer completed does not throw', () async {
        final expected = {'@rv_am': 42};
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          streamCtrl.add(
            _latencyResponse(sshnpdAtSign, clientAtSign, device, expected),
          );
          return NotificationResult();
        });

        final result = await rs.fetchDeviceLatencies({
          '@rv_am': {'ipaddr': '1.2.3.4', 'port': 443},
        });
        expect(result, expected);

        // subscription was already cancelled; second emission must not crash
        streamCtrl.add(
          _latencyResponse(sshnpdAtSign, clientAtSign, device, {'@rv_am': 99}),
        );
      });
    });

    // -----------------------------------------------------------------------
    // selectBestRelay
    // -----------------------------------------------------------------------
    group('selectBestRelay', () {
      const rv1 = '@rv_am';
      const rv2 = '@rv_eu';

      /// Emit discover responses for all [rvs] on each notify call up to
      /// [rvCount], then emit the device latency response.  Emitting all
      /// discover responses every time is safe: the isCompleted guard in
      /// requestRelayIpAddress silently drops duplicates.
      void setupNotify({
        required Map<String, Map<String, dynamic>> ipMap,
        required Map<String, int> deviceLatencies,
        Set<String> skipDiscoverFor = const {},
      }) {
        int callCount = 0;
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
            onSuccess: any(named: 'onSuccess'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((_) async {
          callCount++;
          if (callCount <= ipMap.length) {
            for (final e in ipMap.entries) {
              if (!skipDiscoverFor.contains(e.key)) {
                streamCtrl.add(
                  _discoverResponse(e.key, clientAtSign, e.value),
                );
              }
            }
          } else {
            streamCtrl.add(
              _latencyResponse(sshnpdAtSign, clientAtSign, device, deviceLatencies),
            );
          }
          return NotificationResult();
        });
      }

      test('selects RV with lowest combined average latency', () async {
        setupNotify(
          ipMap: {
            rv1: {'ipaddr': '1.2.3.4', 'port': 443},
            rv2: {'ipaddr': '1.2.3.5', 'port': 443},
          },
          deviceLatencies: {rv1: 10, rv2: 100},
        );
        rs.latencyMeasurer = (_) async => {rv1: 20, rv2: 90}; // rv1 avg=15, rv2 avg=95

        final result = await rs.selectBestRelay(
          rvAtSigns: [rv1.toAtsign(), rv2.toAtsign()],
        );
        expect(result, rv1);
      });

      test('throws StateError when no RV IPs resolve', () {
        // notify does nothing → no discover_response arrives → all timeout
        expect(
          () => rs.selectBestRelay(
            rvAtSigns: [rv1.toAtsign()],
            requestTimeout: const Duration(milliseconds: 50),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('partial IP resolution — selects best from resolved RVs only', () async {
        // rv1 has no discover response; rv2 responds normally
        setupNotify(
          ipMap: {
            rv1: {'ipaddr': '1.2.3.4', 'port': 443},
            rv2: {'ipaddr': '1.2.3.5', 'port': 443},
          },
          deviceLatencies: {rv2: 30},
          skipDiscoverFor: {rv1},
        );
        rs.latencyMeasurer = (_) async => {rv2: 40};

        final result = await rs.selectBestRelay(
          rvAtSigns: [rv1.toAtsign(), rv2.toAtsign()],
          requestTimeout: const Duration(milliseconds: 50),
        );
        expect(result, rv2);
      });

      test('throws StateError when all client latencies are -1', () {
        setupNotify(
          ipMap: {
            rv1: {'ipaddr': '1.2.3.4', 'port': 443},
            rv2: {'ipaddr': '1.2.3.5', 'port': 443},
          },
          deviceLatencies: {rv1: 10, rv2: 20},
        );
        rs.latencyMeasurer = (_) async => {rv1: -1, rv2: -1};

        expect(
          () => rs.selectBestRelay(rvAtSigns: [rv1.toAtsign(), rv2.toAtsign()]),
          throwsA(isA<StateError>()),
        );
      });

      test('single resolved RV is returned', () async {
        setupNotify(
          ipMap: {rv1: {'ipaddr': '1.2.3.4', 'port': 443}},
          deviceLatencies: {rv1: 15},
        );
        rs.latencyMeasurer = (_) async => {rv1: 10};

        final result = await rs.selectBestRelay(rvAtSigns: [rv1.toAtsign()]);
        expect(result, rv1);
      });

      test('latency tie — a winner is returned without throwing', () async {
        setupNotify(
          ipMap: {
            rv1: {'ipaddr': '1.2.3.4', 'port': 443},
            rv2: {'ipaddr': '1.2.3.5', 'port': 443},
          },
          deviceLatencies: {rv1: 10, rv2: 10},
        );
        rs.latencyMeasurer = (_) async => {rv1: 10, rv2: 10};

        final result = await rs.selectBestRelay(
          rvAtSigns: [rv1.toAtsign(), rv2.toAtsign()],
        );
        expect(result, anyOf(rv1, rv2));
      });

    });

    // -----------------------------------------------------------------------
    // lowestAverageLatency
    // -----------------------------------------------------------------------
    group('lowestAverageLatency', () {
      test('picks correct winner', () {
        final result = rs.lowestAverageLatency(
          {'@rv_am': 10, '@rv_eu': 100},
          {'@rv_am': 20, '@rv_eu': 90},
        );
        expect(result.toString(), '@rv_am');
      });

      test('throws StateError on empty maps', () {
        expect(
          () => rs.lowestAverageLatency({}, {}),
          throwsA(isA<StateError>()),
        );
      });

      test('skips RV unreachable by device (-1 daemon)', () {
        expect(
          rs.lowestAverageLatency(
            {'@rv_am': -1, '@rv_eu': 80},
            {'@rv_am': 10, '@rv_eu': 90},
          ).toString(),
          '@rv_eu',
        );
      });

      test('skips RV unreachable by client (-1 client)', () {
        expect(
          rs.lowestAverageLatency(
            {'@rv_am': 10, '@rv_eu': 80},
            {'@rv_am': -1, '@rv_eu': 90},
          ).toString(),
          '@rv_eu',
        );
      });

      test('single valid RV is returned', () {
        expect(
          rs.lowestAverageLatency({'@rv_am': 50}, {'@rv_am': 50}).toString(),
          '@rv_am',
        );
      });

      test('all RVs have -1 → StateError', () {
        expect(
          () => rs.lowestAverageLatency(
            {'@rv_am': -1, '@rv_eu': -1},
            {'@rv_am': -1, '@rv_eu': -1},
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('RV in daemon map but absent from client map is skipped', () {
        // @rv_ap has no client latency → clientLatencies['@rv_ap'] == null → -1
        expect(
          rs.lowestAverageLatency(
            {'@rv_ap': 5, '@rv_eu': 80},
            {'@rv_eu': 90}, // @rv_ap absent
          ).toString(),
          '@rv_eu',
        );
      });

      test('three-way tie returns a result without throwing', () {
        expect(
          () => rs.lowestAverageLatency(
            {'@rv_am': 10, '@rv_eu': 10, '@rv_ap': 10},
            {'@rv_am': 10, '@rv_eu': 10, '@rv_ap': 10},
          ),
          returnsNormally,
        );
      });
    });
  });
}
