import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'sshnpd_channel_mocks.dart';

/// Serves [devices] (device names by daemon atSign) as the `device_info`
/// records a listing scans for.
class _ListingChannel extends StubbedSshnpdChannel {
  _ListingChannel({
    required super.atClient,
    required super.params,
    required super.subscribe,
    required this.devices,
  }) : super(
          sessionId: Uuid().v4(),
          namespace: 'sshnp',
          notify: (_, __,
                  {required checkForFinalDeliveryStatus,
                  required waitForFinalDeliveryStatus,
                  required ttln,
                  maxTries = 3}) async =>
              NotificationResult(),
        );

  final Map<String, List<String>> devices;

  @override
  Future<List<AtKey>> getAtKeysRemote({
    String? regex,
    String? sharedBy,
    String? sharedWith,
    bool showHiddenKeys = false,
  }) async =>
      [
        for (final MapEntry(key: daemon, value: names) in devices.entries)
          if (sharedBy == null || sharedBy == daemon)
            for (final name in names)
              AtKey.fromString('@client:device_info.$name.sshnp$daemon'),
      ];
}

void main() {
  group("Given a client listing @daemon's devices", () {
    late StreamController<AtNotification> notifications;
    late List<AtNotification> delivered;
    late List<Object> uncaught;

    setUp(() {
      notifications = StreamController<AtNotification>.broadcast();
      delivered = [];
      uncaught = [];
      registerFallbackValue(AtKey());
    });

    tearDown(() => notifications.close());

    _ListingChannel channel(
      Map<String, List<String>> devices, {
      String sshnpdAtSign = '@daemon',
    }) {
      final params = MockSshnpParams();
      when(() => params.verbose).thenReturn(false);
      when(() => params.device).thenReturn('ignored');
      when(() => params.clientAtSign).thenReturn('@client');
      when(() => params.sshnpdAtSign).thenReturn(sshnpdAtSign);
      final atClient = MockAtClient();
      when(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as AtKey;
        return AtValue()
          ..value = jsonEncode(
              {'devicename': key.key.replaceFirst('device_info.', '')});
      });
      return _ListingChannel(
        atClient: atClient,
        params: params,
        devices: devices,
        // Delivers what the regex matches, as at_client does.
        subscribe: ({regex, shouldDecrypt = false}) => notifications.stream
            .where((n) => RegExp(regex ?? '').hasMatch(n.key))
            .map((n) {
          delivered.add(n);
          return n;
        }),
      );
    }

    AtNotification heartbeat(String daemon, String? value, {String? device}) =>
        AtNotification(
          Uuid().v4(),
          '@client:heartbeat.${device ?? 'dev1'}.sshnp$daemon',
          daemon,
          '@client',
          1,
          'key',
          true,
          value: value,
        );

    String heartbeatFrom(String device) => jsonEncode({'devicename': device});

    /// Lists [c]'s devices while [heartbeats] arrive, recording any error that
    /// escapes the heartbeat listener.
    Future<SshnpDeviceList> list(
      _ListingChannel c,
      List<AtNotification> heartbeats,
    ) async {
      final listing = Completer<SshnpDeviceList>();
      unawaited(runZonedGuarded(
        () => c
            .listDevices(waitDuration: const Duration(milliseconds: 300))
            .then(listing.complete),
        (e, _) => uncaught.add(e),
      ));
      await pumpEventQueue();
      for (final h in heartbeats) {
        notifications.add(h);
      }
      return listing.future;
    }

    test(
        "when @daemon's device dev1 sends a heartbeat, then dev1 is listed as"
        ' active', () async {
      final devices = await list(
        channel({
          '@daemon': ['dev1'],
        }),
        [heartbeat('@daemon', heartbeatFrom('dev1'))],
      );

      expect(devices.activeDevices, {'dev1'});
      expect(uncaught, isEmpty);
    });

    test(
        "when @daemon2 sends a heartbeat for dev1, then the subscription doesn't"
        " deliver it, and dev1 isn't listed as active", () async {
      final devices = await list(
        channel({
          '@daemon': ['dev1'],
        }),
        [heartbeat('@daemon2', heartbeatFrom('dev1'))],
      );

      expect(delivered, isEmpty);
      expect(devices.activeDevices, isEmpty);
      expect(devices.info.keys, contains('dev1'));
    });

    test(
        "when @daemon sends a heartbeat that isn't JSON, or has no devicename,"
        ' then the listing carries on and still lists the other devices',
        () async {
      final devices = await list(
        channel({
          '@daemon': ['dev1', 'dev2'],
        }),
        [
          heartbeat('@daemon', 'not json'),
          heartbeat('@daemon', jsonEncode({'version': '1.0.0'})),
          heartbeat('@daemon', heartbeatFrom('dev2'), device: 'dev2'),
        ],
      );

      expect(uncaught, isEmpty, reason: 'no error escapes the listener');
      expect(devices.activeDevices, {'dev2'});
      expect(devices.info.keys, containsAll(['dev1', 'dev2']));
    });
  });

  group(
      'Given a client listing devices for every daemon atSign that shares'
      ' device info with it', () {
    late StreamController<AtNotification> notifications;
    late List<Object> uncaught;

    setUp(() {
      notifications = StreamController<AtNotification>.broadcast();
      uncaught = [];
      registerFallbackValue(AtKey());
    });

    tearDown(() => notifications.close());

    test(
        "when @d2's device dev1 sends a heartbeat, then dev1@d2 is listed as"
        " active, and dev1@d1 isn't", () async {
      final params = MockSshnpParams();
      when(() => params.verbose).thenReturn(false);
      when(() => params.device).thenReturn('ignored');
      when(() => params.clientAtSign).thenReturn('@client');
      when(() => params.sshnpdAtSign).thenReturn('');
      final atClient = MockAtClient();
      when(
        () => atClient.get(
          any(),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as AtKey;
        return AtValue()
          ..value = jsonEncode(
              {'devicename': key.key.replaceFirst('device_info.', '')});
      });
      final c = _ListingChannel(
        atClient: atClient,
        params: params,
        devices: {
          '@d1': ['dev1'],
          '@d2': ['dev1'],
        },
        // Delivers what the regex matches, as at_client does.
        subscribe: ({regex, shouldDecrypt = false}) => notifications.stream
            .where((n) => RegExp(regex ?? '').hasMatch(n.key)),
      );

      final listing = Completer<SshnpDeviceList>();
      unawaited(runZonedGuarded(
        () => c
            .listDevices(waitDuration: const Duration(milliseconds: 300))
            .then(listing.complete),
        (e, _) => uncaught.add(e),
      ));
      await pumpEventQueue();
      notifications.add(AtNotification(
        Uuid().v4(),
        '@client:heartbeat.dev1.sshnp@d2',
        '@d2',
        '@client',
        1,
        'key',
        true,
        value: jsonEncode({'devicename': 'dev1'}),
      ));
      final devices = await listing.future;

      expect(devices.info.keys, containsAll(['dev1@d1', 'dev1@d2']));
      expect(devices.activeDevices, {'dev1@d2'});
      expect(uncaught, isEmpty);
    });
  });
}
