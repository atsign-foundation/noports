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
        RegExp(SrvdImpl.subscriptionRegex)
            .hasMatch('jagan@test.${Srvd.namespace}@jagan'),
        true);
    expect(RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}@'),
        true);
    expect(
        RegExp(SrvdImpl.subscriptionRegex).hasMatch('${Srvd.namespace}.test@'),
        false);
  });

  group('A group of test related notifications received from sshnp', () {
    test('A test to verify srvd notification returns local ports', () async {
      registerFallbackValue(FakeNotificationParams());
      registerFallbackValue(FakeAtKey());

      String atSign = '@bob';
      String managerAtsign = '@alice';

      MockAtClient mockAtClient = MockAtClient();
      MockNotificationService mockNotificationService =
          MockNotificationService();

      when(() => mockAtClient.notificationService)
          .thenReturn(mockNotificationService);

      when(() => mockNotificationService.notify(any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          onSentToSecondary:
              any(named: 'onSentToSecondary'))).thenAnswer(
          expectAsync1((Invocation invocation) async {
        // Assert the notification response which will be sent to sshnp
        var hostAndPortsList =
            invocation.positionalArguments[0].value.split(',');
        expect(hostAndPortsList[0], '127.0.0.1');
        expect(hostAndPortsList[1].isNotEmpty, true);
        expect(hostAndPortsList[2].isNotEmpty, true);
        expect(hostAndPortsList[3].isNotEmpty, true);
        return NotificationResult()
          ..notificationStatusEnum = NotificationStatusEnum.delivered;
      }));

      when(() => mockAtClient.get(any(that: FakeAtKeyMatcher()))).thenAnswer(
          (_) async => Future.value(AtValue()..value = 'dummy-public-key'));

      Srvd srvd = SrvdImpl(
          atClient: mockAtClient,
          atSign: atSign,
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          managerAtsign: managerAtsign,
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false);

      // Create a stream controller to simulate the notification received from the sshnp
      final streamController = StreamController<AtNotification>();
      streamController.add(AtNotification(
          'a8d79920-1441-4e07-b8e1-3dee400bddd0',
          '@sitaram:local.request_ports.sshrvd@alice',
          '@sitaram',
          '@alice',
          123,
          'key',
          true)
        ..value =
            '{"sessionId":"21a4c11e-7e67-45c3-9e52-48d380fa9589","atSignA":"@alice","atSignB":"@bob","authenticateSocketA":true,"authenticateSocketB":true,"clientNonce":"2024-08-03T23:37:30.477614"}');
      when(() => mockNotificationService.subscribe(
              regex: any(named: 'regex'),
              shouldDecrypt: any(named: 'shouldDecrypt')))
          .thenAnswer((_) => streamController.stream);

      await srvd.init();
      // Starts listening on the notifications with regex "sshrvd". Upon receiving the notification,
      // returns two ports for the client to communicate with the device.
      // The notification response which contains host and ports numbers are asserted in the mockNotificationService.notify.
      await srvd.run();
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
