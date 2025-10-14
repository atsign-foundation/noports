import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/srvd.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

class FakeAtKey extends Fake implements AtKey {}

void main() {
  test('Test notification subscription regex', () {
    expect(
      RegExp(
        SrvdImpl.subscriptionRegex,
      ).hasMatch('jagan@test.${Srvd.namespace}@jagan'),
      true,
    );
    expect(
      RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}@'),
      false,
    );
    expect(
      RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}.test@'),
      false,
    );
    expect(
      RegExp(
        SrvdImpl.subscriptionRegex,
      ).hasMatch('foo.${Srvd.namespace}.test@'),
      false,
    );
  });

  group('A group of test related notifications received from sshnp', () {
    test('A test to verify srvd notification returns local ports', () async {
      registerFallbackValue(FakeNotificationParams());
      registerFallbackValue(FakeAtKey());

      String atSign = '@bob';
      String relayAtSign = '@alice';

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
        atSign: atSign,
        homeDirectory: Directory.current.path,
        atKeysFilePath: Directory.current.path,
        managerAtsign: relayAtSign,
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
          '@sitaram:local.request_ports.sshrvd@alice',
          '@sitaram',
          '@alice',
          123,
          'key',
          true,
        )..value =
            '{"sessionId":"21a4c11e-7e67-45c3-9e52-48d380fa9589","atSignA":"@alice","atSignB":"@bob","authenticateSocketA":true,"authenticateSocketB":true,"clientNonce":"2024-08-03T23:37:30.477614"}',
      );
      when(
        () => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((i) {
        switch (i.namedArguments[Symbol('regex')]) {
          case '\\.sshrvd@':
            print('Returning streamController.stream');
            return streamController.stream;
          default:
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
