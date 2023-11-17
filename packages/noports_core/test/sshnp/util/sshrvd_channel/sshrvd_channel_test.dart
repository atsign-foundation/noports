import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_utils.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/sshrv.dart';
import 'package:noports_core/sshrvd.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'sshrvd_channel_mocks.dart';

void main() {
  group('SshrvdChannel', () {
    late SshrvGeneratorStub<String> sshrvGeneratorStub;
    late MockAtClient mockAtClient;
    late MockNotificationService mockNotificationService;
    late StreamController<AtNotification> notificationController;
    late FunctionStub notifyStub;
    late MockSshnpParams mockParams;
    late String sessionId;
    late StubbedSshrvdChannel stubbedSshrvdChannel;

    setUp(() {
      sshrvGeneratorStub = SshrvGeneratorStub();
      mockAtClient = MockAtClient();
      mockNotificationService = MockNotificationService();
      notificationController = StreamController();
      notifyStub = FunctionStub();
      mockParams = MockSshnpParams();
      sessionId = Uuid().v4();

      stubbedSshrvdChannel = StubbedSshrvdChannel<String>(
          atClient: mockAtClient,
          params: mockParams,
          sessionId: sessionId,
          sshrvGenerator: sshrvGeneratorStub,
          notify: (_, __) async {
            final testIp = '123.123.123.123';
            final portA = 10456;
            final portB = 10789;

            notificationController.add(
              AtNotification.empty()
                ..id = Uuid().v4()
                ..key = '$sessionId.${Sshrvd.namespace}'
                ..from = '@sshrvd'
                ..to = '@client'
                ..epochMillis = DateTime.now().millisecondsSinceEpoch
                ..value = '$testIp,$portA,$portB',
            );
            notifyStub.call();
          });

      registerFallbackValue(AtKey());
      registerFallbackValue(NotificationParams.forUpdate(AtKey()));
    });

    test('public API', () {
      // This doesn't cover the full public API, but it covers all of the public
      // members which do not need further tests

      // Base type
      expect(stubbedSshrvdChannel, isA<SshrvdChannel<String>>());
      expect(stubbedSshrvdChannel, isA<AsyncInitialization>());
      expect(stubbedSshrvdChannel, isA<AtClientBindings>());

      // final params
      expect(stubbedSshrvdChannel.logger, isA<AtSignLogger>());
      expect(
        stubbedSshrvdChannel.sshrvGenerator,
        isA<Sshrv<String> Function(String, int, {int localSshdPort})>(),
      );
      expect(stubbedSshrvdChannel.atClient, mockAtClient);
      expect(stubbedSshrvdChannel.params, mockParams);
      expect(stubbedSshrvdChannel.sessionId, sessionId);
    }); // test public API

    test('Initialization - sshrvd host', () async {
      /// Set the required parameters
      when(() => mockParams.host).thenReturn('@sshrvd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.clientAtSign).thenReturn('@client');

      when(
        () => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      ).thenAnswer((_) => notificationController.stream);

      when(() => mockAtClient.notificationService)
          .thenReturn(mockNotificationService);

      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.notAcknowledged);
      expect(stubbedSshrvdChannel.initalizeStarted, false);

      verifyNever(
        () => mockNotificationService.subscribe(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        ),
      );
      verifyNever(
        () => mockNotificationService.notify(any()),
      );

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);

      verifyInOrder([
        () => mockNotificationService.subscribe(
              regex: any(named: 'regex'),
              shouldDecrypt: any(named: 'shouldDecrypt'),
            ),
        () => notifyStub.call(),
      ]);

      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.acknowledged);
      expect(stubbedSshrvdChannel.host, '123.123.123.123');
      expect(stubbedSshrvdChannel.port, 10456);
      expect(stubbedSshrvdChannel.sshrvdPort, 10789);
    }); // test Initialization - sshrvd host
  }); // group SshrvdChannel
}
