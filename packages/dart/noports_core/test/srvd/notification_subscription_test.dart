import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

class FakeAtKey extends Fake implements AtKey {}

void main() {
  group('A group of test related notifications received from sshnp', () {
    test('A test to verify srvd notification returns local ports', () async {
      registerFallbackValue(FakeNotificationParams());
      registerFallbackValue(FakeAtKey());

      String clientAtsign = '@alice';
      String daemonAtsign = '@bob';
      String relayAtSign = '@relay';

      MockAtClient mockAtClient = MockAtClient();
      MockNotificationService mockNotificationService =
          MockNotificationService();

      when(() => mockAtClient.getCurrentAtSign()).thenReturn(relayAtSign);
      when(
        () => mockAtClient.notificationService,
      ).thenReturn(mockNotificationService);

      when(
        () => mockAtClient.put(
          any(),
          any(),
          putRequestOptions: any(named: 'putRequestOptions'),
        ),
      ).thenAnswer((_) => Future.value(true));
      Completer<NotificationParams> notificationReceived =
          Completer<NotificationParams>();
      when(
        () => mockNotificationService.notify(
          any(),
          checkForFinalDeliveryStatus: any(
            named: 'checkForFinalDeliveryStatus',
          ),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSentToSecondary: any(named: 'onSentToSecondary'),
        ),
      ).thenAnswer((Invocation i) async {
        notificationReceived.complete(i.positionalArguments[0]);
        return NotificationResult()
          ..notificationStatusEnum = NotificationStatusEnum.delivered;
      });

      when(() => mockAtClient.get(any(that: FakeAtKeyMatcher()))).thenAnswer(
        (_) async => Future.value(AtValue()..value = 'dummy-public-key'),
      );

      Srvd srvd = SrvdImpl(
        atClient: mockAtClient,
        atSign: relayAtSign.toAtsign(),
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: 'open',
        ipAddress: '127.0.0.1',
        logTraffic: false,
        verbose: false,
        bind443: false,
        localBindPort443: 443,
      );

      // Create a stream controller to simulate the notification received from the sshnp
      final streamController = StreamController<AtNotification>();
      final otherStreamController = StreamController<AtNotification>();
      streamController.add(
        AtNotification(
            'a8d79920-1441-4e07-b8e1-3dee400bddd0',
            '$relayAtSign:local.request_ports.sshrvd$clientAtsign',
            clientAtsign, // from
            relayAtSign, // to
            123,
            'key',
            true,
          )
          ..value =
              '{"sessionId":"21a4c11e-7e67-45c3-9e52-48d380fa9589","atSignA":"$clientAtsign","atSignB":"$daemonAtsign","authenticateSocketA":true,"authenticateSocketB":true,"clientNonce":"2024-08-03T23:37:30.477614"}',
      );
      when(
        () => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((i) {
        final regex = i.namedArguments[Symbol('regex')];
        switch (regex) {
          case '\\.sshrvd@':
            print(
              '.subscribe mock handler returning streamController.stream for regex $regex',
            );
            return streamController.stream;
          default:
            print(
              '.subscribe mock handler returning OTHERstreamController.stream for regex $regex',
            );
            return otherStreamController.stream;
        }
      });

      await srvd.init();
      // Starts listening on the notifications with regex "sshrvd". Upon receiving the notification,
      // returns two ports for the client to communicate with the device.
      // The notification response which contains host and ports numbers are asserted in the mockNotificationService.notify.
      await srvd.run();

      NotificationParams n = await notificationReceived.future;
      var hostAndPortsList = n.value!.split(',');
      expect(hostAndPortsList[0], '127.0.0.1');
      expect(hostAndPortsList[1].isNotEmpty, true);
      expect(hostAndPortsList[2].isNotEmpty, true);
      expect(hostAndPortsList[3].isNotEmpty, true);
    });

    group('discover_request', () {
      const String clientAtsign = '@alice';
      const String relayAtSign = '@relay';

      late MockAtClient mockAtClient;
      late MockNotificationService mockNotificationService;
      late Completer<NotificationParams> notificationReceived;
      late StreamController<AtNotification> sshrvdStream;

      setUpAll(() {
        registerFallbackValue(FakeNotificationParams());
        registerFallbackValue(FakeAtKey());
      });

      setUp(() {
        mockAtClient = MockAtClient();
        mockNotificationService = MockNotificationService();
        notificationReceived = Completer<NotificationParams>();
        sshrvdStream = StreamController<AtNotification>();

        when(() => mockAtClient.getCurrentAtSign()).thenReturn(relayAtSign);
        when(
          () => mockAtClient.notificationService,
        ).thenReturn(mockNotificationService);

        // Capture the outgoing response notification so tests can assert on it.
        when(
          () => mockNotificationService.notify(
            any(),
            checkForFinalDeliveryStatus: any(
              named: 'checkForFinalDeliveryStatus',
            ),
            waitForFinalDeliveryStatus: any(
              named: 'waitForFinalDeliveryStatus',
            ),
            onSentToSecondary: any(named: 'onSentToSecondary'),
          ),
        ).thenAnswer((Invocation i) async {
          notificationReceived.complete(i.positionalArguments[0]);
          return NotificationResult()
            ..notificationStatusEnum = NotificationStatusEnum.delivered;
        });

        // run() makes two subscribe calls: the relay's own `\.sshrvd@` regex
        // and a public-key-change listener with a different regex. Non-broadcast
        // streams can only be listened to once, so each subscribe call needs
        // its own stream. We only care about the sshrvd one; the rest get empty.
        when(
          () => mockNotificationService.subscribe(
            regex: any(named: 'regex'),
            shouldDecrypt: any(named: 'shouldDecrypt'),
          ),
        ).thenAnswer((i) {
          final regex = i.namedArguments[Symbol('regex')];
          if (regex == '\\.sshrvd@') {
            return sshrvdStream.stream;
          }
          return const Stream<AtNotification>.empty();
        });
      });

      SrvdImpl buildSrvd({
        bool bind443 = false,
        int localBindPort443 = 443,
      }) {
        return SrvdImpl(
          atClient: mockAtClient,
          atSign: relayAtSign.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          // discover_request handler doesn't gate on managerAtsign, so this
          // value doesn't affect behavior — using a real-looking atsign rather
          // than the 'open' sentinel to match a typical production config.
          managerAtsign: '@manager',
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: bind443,
          localBindPort443: localBindPort443,
        );
      }

      // Mirrors what RelaySelector sends in production:
      // `<relay>:discover_request.sshrvd<client>`
      AtNotification discoverRequest({
        required String id,
        required String value,
      }) {
        return AtNotification(
            id,
            '$relayAtSign:discover_request.sshrvd$clientAtsign',
            clientAtsign, // from
            relayAtSign, // to
            123,
            'key',
            true,
          )
          ..value = value;
      }

      test('returns ip with null port when bind443 is false', () async {
        final srvd = buildSrvd();

        sshrvdStream.add(
          discoverRequest(
            id: 'b9d79920-1441-4e07-b8e1-3dee400bddd1',
            value: '{"items":["ipaddr","port"]}',
          ),
        );

        await srvd.init();
        await srvd.run();

        NotificationParams n = await notificationReceived.future;

        expect(n.atKey.key, 'discover_response');
        expect(n.atKey.sharedWith, clientAtsign);
        expect(n.atKey.namespace, Srvd.namespace);

        final decoded = jsonDecode(n.value!) as Map<String, dynamic>;
        expect(decoded['ipaddr'], '127.0.0.1');
        expect(decoded.containsKey('port'), true);
        // bind443 is false, so the relay advertises no 443 port.
        expect(decoded['port'], isNull);
      });

      test('returns port 443 when bind443 is true', () async {
        // bind443: true spawns a single-port isolate that binds a real socket.
        // localBindPort443: 0 lets the OS pick a free ephemeral port so the
        // test doesn't need privileges and doesn't collide with anything else.
        // The discover response always reports port 443 (the well-known port
        // clients connect to), independent of localBindPort443.
        final srvd = buildSrvd(bind443: true, localBindPort443: 0);

        addTearDown(() {
          srvd.isolate443?.kill(priority: Isolate.immediate);
        });

        sshrvdStream.add(
          discoverRequest(
            id: 'c9d79920-1441-4e07-b8e1-3dee400bddd2',
            value: '{"items":["ipaddr","port"]}',
          ),
        );

        await srvd.init();
        await srvd.run();

        NotificationParams n = await notificationReceived.future;

        expect(n.atKey.key, 'discover_response');
        expect(n.atKey.sharedWith, clientAtsign);
        expect(n.atKey.namespace, Srvd.namespace);

        final decoded = jsonDecode(n.value!) as Map<String, dynamic>;
        expect(decoded['ipaddr'], '127.0.0.1');
        expect(decoded['port'], 443);
      });
    });
  });
}

class FakeNotificationParamsMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    if (item is NotificationParams) {
      return true;
    }
    return false;
  }
}

class FakeAtKeyMatcher extends Matcher {
  @override
  Description describe(Description description) {
    return description;
  }

  @override
  bool matches(item, Map matchState) {
    if (item is AtKey) {
      return true;
    }
    return false;
  }
}
