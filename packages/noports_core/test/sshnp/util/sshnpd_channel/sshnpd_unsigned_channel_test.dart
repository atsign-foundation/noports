import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_mocks.dart';
import 'sshnpd_channel_mocks.dart';

void main() {
  group('SshnpDefaultChannel', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late String sessionId;
    late String namespace;
    late StreamController<AtNotification> notificationStreamController;
    late SubscribeStub subscribeStub;
    late StubbedSshnpdUnsignedChannel stubbedSshnpdUnsignedChannel;

    // Invocation patterns as closures so they can be referred to by name
    // instead of explicitly writing these calls several times in the test
    subscribeInvocation() => subscribeStub(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        );
    String device = 'myDevice';

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      sessionId = Uuid().v4();
      notificationStreamController = StreamController();
      subscribeStub = SubscribeStub();

      when(() => mockParams.verbose).thenReturn(false);
      when(() => mockParams.device).thenReturn(device);
      namespace = '$device.sshnp';

      stubbedSshnpdUnsignedChannel = StubbedSshnpdUnsignedChannel(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        namespace: namespace,
        subscribe: subscribeStub,
      );

      registerFallbackValue(AtKey());
    });

    whenInitialization() {
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(subscribeInvocation)
          .thenAnswer((_) => notificationStreamController.stream);
    }

    // Same test as on the base class
    test('Initialization', () async {
      whenInitialization();
      expect(stubbedSshnpdUnsignedChannel.sshnpdAck, SshnpdAck.notAcknowledged);
      expect(stubbedSshnpdUnsignedChannel.initializeStarted, false);

      verifyNever(subscribeInvocation);

      // it's okay to call this directly for testing purposes
      await expectLater(stubbedSshnpdUnsignedChannel.initialize(), completes);

      verify(
        () => subscribeStub(
          regex: '$sessionId.$namespace@sshnpd',
          shouldDecrypt: true,
        ),
      ).called(1);
    }); // test Initialization

    test('Initialization completes', () async {
      whenInitialization();
      await expectLater(
        stubbedSshnpdUnsignedChannel.callInitialization(),
        completes,
      );
      await expectLater(stubbedSshnpdUnsignedChannel.initialized, completes);
    }); // test Initialization completes

    test('handleSshnpdPayload', () async {
      AtNotification notification = AtNotification.empty()..value = 'connected';
      Future<SshnpdAck> ack =
          stubbedSshnpdUnsignedChannel.handleSshnpdPayload(notification);

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledged);
    }); // test handleSshnpdPayload

    test('handleSshnpdPayload - not "connected"', () async {
      AtNotification notification = AtNotification.empty()
        ..value = 'jaskldfjlsdflk';
      Future<SshnpdAck> ack =
          stubbedSshnpdUnsignedChannel.handleSshnpdPayload(notification);

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledgedWithErrors);
    }); // test handleSshnpdPayload
  }); // group SshnpDefaultChannel
}
