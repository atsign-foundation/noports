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
    late StreamController<AtNotification> notificationStreamController;
    late FunctionStub notifyStub;
    late SubscribeStub subscribeStub;
    late MockSshnpParams mockParams;
    late String sessionId;
    late StubbedSshrvdChannel stubbedSshrvdChannel;
    late MockSshrv<String> mockSshrv;

    // Invocation patterns as closures so they can be referred to by name
    // instead of explicitly writing these calls several times in the test
    notifyInvocation() => notifyStub();
    subscribeInvocation() => subscribeStub();
    sshrvGeneratorInvocation() => sshrvGeneratorStub(
          any(),
          any(),
          localSshdPort: any(named: 'localSshdPort'),
        );
    sshrvRunInvocation() => mockSshrv.run();

    setUp(() {
      sshrvGeneratorStub = SshrvGeneratorStub();
      mockAtClient = MockAtClient();
      notificationStreamController = StreamController();
      notifyStub = FunctionStub();
      subscribeStub = SubscribeStub();
      mockParams = MockSshnpParams();
      sessionId = Uuid().v4();
      mockSshrv = MockSshrv();

      stubbedSshrvdChannel = StubbedSshrvdChannel<String>(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        sshrvGenerator: sshrvGeneratorStub,
        notify: (_, __) async {
          final testIp = '123.123.123.123';
          final portA = 10456;
          final portB = 10789;

          notificationStreamController.add(
            AtNotification.empty()
              ..id = Uuid().v4()
              ..key = '$sessionId.${Sshrvd.namespace}'
              ..from = '@sshrvd'
              ..to = '@client'
              ..epochMillis = DateTime.now().millisecondsSinceEpoch
              ..value = '$testIp,$portA,$portB',
          );
          notifyStub();
        },
        subscribe: ({regex, shouldDecrypt = false}) {
          return subscribeStub();
        },
      );

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

    whenInitializationWithSshrvdHost() {
      when(() => mockParams.host).thenReturn('@sshrvd');
      when(() => mockParams.device).thenReturn('mydevice');
      when(() => mockParams.clientAtSign).thenReturn('@client');

      when(subscribeInvocation)
          .thenAnswer((_) => notificationStreamController.stream);
    }

    test('Initialization - sshrvd host', () async {
      /// Set the required parameters
      whenInitializationWithSshrvdHost();

      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.notAcknowledged);
      expect(stubbedSshrvdChannel.initalizeStarted, false);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);

      verifyInOrder([
        subscribeInvocation,
        notifyInvocation,
      ]);

      verifyNever(subscribeInvocation);
      verifyNever(notifyInvocation);

      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.acknowledged);
      expect(stubbedSshrvdChannel.host, '123.123.123.123');
      expect(stubbedSshrvdChannel.port, 10456);
      expect(stubbedSshrvdChannel.sshrvdPort, 10789);
    }); // test Initialization - sshrvd host

    test('Initialization - non-sshrvd host', () async {
      when(() => mockParams.host).thenReturn('234.234.234.234');
      when(() => mockParams.port).thenReturn(135);

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);

      expect(stubbedSshrvdChannel.host, '234.234.234.234');
      expect(stubbedSshrvdChannel.port, 135);
    }); // test Initialization - non-sshrvd host

    test('runSshrv', () async {
      whenInitializationWithSshrvdHost();

      await expectLater(stubbedSshrvdChannel.callInitialization(), completes);
      expect(stubbedSshrvdChannel.sshrvdAck, SshrvdAck.acknowledged);
      await expectLater(stubbedSshrvdChannel.initialized, completes);
      // Initialization should be complete
      // Begin test for [runSshrv()]

      when(() => mockParams.localSshdPort).thenReturn(23);
      when(sshrvGeneratorInvocation).thenReturn(mockSshrv);
      when(sshrvRunInvocation).thenAnswer((_) async => 'called sshrv run');

      verifyNever(sshrvGeneratorInvocation);
      verifyNever(sshrvRunInvocation);

      await expectLater(
        await stubbedSshrvdChannel.runSshrv(),
        'called sshrv run',
      );

      verifyInOrder([
        sshrvGeneratorInvocation,
        sshrvRunInvocation,
      ]);

      verifyNever(sshrvGeneratorInvocation);
      verifyNever(sshrvRunInvocation);
    }); // test runSshrv
  }); // group SshrvdChannel
}
