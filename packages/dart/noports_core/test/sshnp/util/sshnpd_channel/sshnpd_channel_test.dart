import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_core_constants.dart';
import '../../sshnp_mocks.dart';
import '../sshnp_ssh_key_handler/sshnp_ssh_key_handler_mocks.dart';
import 'sshnpd_channel_mocks.dart';

void main() {
  group('SshnpdChannel', () {
    late MockAtClient mockAtClient;
    late MockSshnpParams mockParams;
    late String sessionId;
    late String namespace;
    late StreamController<AtNotification> notificationStreamController;
    late NotifyStub notifyStub;
    late SubscribeStub subscribeStub;
    late HandleSshnpdPayloadStub payloadStub;
    late StubbedSshnpdChannel stubbedSshnpdChannel;

    // Invocation patterns as closures so they can be referred to by name
    // instead of explicitly writing these calls several times in the test
    notifyInvocation() => notifyStub(
          any(),
          any(),
          checkForFinalDeliveryStatus:
              any(named: 'checkForFinalDeliveryStatus'),
          waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
          ttln: any(named: 'ttln'),
        );
    subscribeInvocation() => subscribeStub(
          regex: any(named: 'regex'),
          shouldDecrypt: any(named: 'shouldDecrypt'),
        );
    payloadInvocation() => payloadStub(any());
    String device = 'myDevice';

    setUp(() {
      mockAtClient = MockAtClient();
      mockParams = MockSshnpParams();
      when(() => mockParams.verbose).thenReturn(false);
      sessionId = Uuid().v4();
      notificationStreamController = StreamController();
      notifyStub = NotifyStub();
      subscribeStub = SubscribeStub();
      payloadStub = HandleSshnpdPayloadStub();

      when(() => mockParams.device).thenReturn(device);
      namespace = '$device.sshnp';

      stubbedSshnpdChannel = StubbedSshnpdChannel(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        namespace: namespace,
        notify: notifyStub.call,
        subscribe: subscribeStub.call,
        handleSshnpdPayload: payloadStub.call,
      );

      registerFallbackValue(AtKey());
      registerFallbackValue(Duration(minutes: 1));
      registerFallbackValue(AtNotification.empty());
    });

    test('public API', () {
      expect(stubbedSshnpdChannel.atClient, mockAtClient);
      expect(stubbedSshnpdChannel.params, mockParams);
      expect(stubbedSshnpdChannel.sessionId, sessionId);
      expect(stubbedSshnpdChannel.namespace, namespace);
    }); // test public API

    whenInitialization() {
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(subscribeInvocation)
          .thenAnswer((_) => notificationStreamController.stream);
    }

    test('Initialization', () async {
      whenInitialization();
      expect(stubbedSshnpdChannel.sshnpdAck, SshnpdAck.notAcknowledged);
      expect(stubbedSshnpdChannel.initializeStarted, false);

      verifyNever(subscribeInvocation);

      // it's okay to call this directly for testing purposes
      await expectLater(stubbedSshnpdChannel.initialize(), completes);

      verify(
        () => subscribeStub(
          regex: '$sessionId.$namespace@sshnpd',
          shouldDecrypt: true,
        ),
      ).called(1);
    }); // test Initialization

    group('handleSshnpdResponses', () {
      test('handleSshnpdResponses', () async {
        whenInitialization();
        await expectLater(stubbedSshnpdChannel.initialize(), completes);
        when(payloadInvocation).thenAnswer((_) async => SshnpdAck.acknowledged);

        Future<SshnpdAck> ack = stubbedSshnpdChannel.waitForDaemonResponse();

        // manually add a notification to the stream
        final String notificationId = Uuid().v4();
        notificationStreamController.add(
          AtNotification.empty()
            ..id = notificationId
            ..to = '@client'
            ..from = '@sshnpd'
            ..key = '$sessionId.$namespace@sshnpd',
        );

        await expectLater(ack, completes);

        verify(
          () => payloadStub(
            any<AtNotification>(
              that: predicate(
                (AtNotification notification) =>
                    notification.id == notificationId,
              ),
            ),
          ),
        ).called(1);

        expect(stubbedSshnpdChannel.sshnpdAck, SshnpdAck.acknowledged);
      }); // test handleSshnpdResponses

      test('handleSshnpdResponses - acknowledged with errors', () async {
        whenInitialization();
        await expectLater(stubbedSshnpdChannel.initialize(), completes);
        when(payloadInvocation)
            .thenAnswer((_) async => SshnpdAck.acknowledgedWithErrors);

        Future<SshnpdAck> ack = stubbedSshnpdChannel.waitForDaemonResponse();

        // manually add a notification to the stream
        final String notificationId = Uuid().v4();
        notificationStreamController.add(
          AtNotification.empty()
            ..id = notificationId
            ..to = '@client'
            ..from = '@sshnpd'
            ..key = '$sessionId.$namespace@sshnpd',
        );

        await expectLater(ack, completes);

        verify(
          () => payloadStub(
            any<AtNotification>(
              that: predicate(
                (AtNotification notification) =>
                    notification.id == notificationId,
              ),
            ),
          ),
        ).called(1);

        expect(
            stubbedSshnpdChannel.sshnpdAck, SshnpdAck.acknowledgedWithErrors);
      }); // test handleSshnpdResponses - acknowledged with errors

      test('handleSshnpdResponses - not acknowledged', () async {
        whenInitialization();
        await expectLater(stubbedSshnpdChannel.initialize(), completes);
        when(payloadInvocation)
            .thenAnswer((_) async => SshnpdAck.notAcknowledged);

        Future<SshnpdAck> ack =
            stubbedSshnpdChannel.waitForDaemonResponse(maxWaitMillis: 300);

        // manually add a notification to the stream
        final String notificationId = Uuid().v4();
        notificationStreamController.add(
          AtNotification.empty()
            ..id = notificationId
            ..to = '@client'
            ..from = '@sshnpd'
            ..key = '$sessionId.$namespace@sshnpd',
        );

        await expectLater(ack, completes);

        verify(
          () => payloadStub(
            any<AtNotification>(
              that: predicate(
                (AtNotification notification) =>
                    notification.id == notificationId,
              ),
            ),
          ),
        ).called(1);

        expect(stubbedSshnpdChannel.sshnpdAck, SshnpdAck.notAcknowledged);
      }); // test handleSshnpdResponses - not acknowledged
    }); // group handleSshnpdResponses

    group('sharePublicKeyIfRequired', () {
      test('sharePublicKeyIfRequired', () async {
        when(() => mockParams.sendSshPublicKey).thenReturn(true);
        MockAtSshKeyPair identityKeyPair = MockAtSshKeyPair();

        when(() => identityKeyPair.publicKeyContents)
            .thenReturn(TestingKeyPair.public);

        when(() => mockParams.clientAtSign).thenReturn('@client');
        when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

        when(
          () => notifyStub(
            any<AtKey>(
                that: predicate((AtKey key) => key.key == 'sshpublickey')),
            any(),
            checkForFinalDeliveryStatus:
                any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus:
                any(named: 'waitForFinalDeliveryStatus'),
            ttln: any(named: 'ttln'),
          ),
        ).thenAnswer((_) async {});

        verifyNever(notifyInvocation);

        await expectLater(
          stubbedSshnpdChannel.sharePublicKeyIfRequired(identityKeyPair),
          completes,
        );

        verify(
          () => notifyStub(
            any<AtKey>(
                that: predicate((AtKey key) => key.key == 'sshpublickey')),
            TestingKeyPair.public,
            checkForFinalDeliveryStatus:
                any(named: 'checkForFinalDeliveryStatus'),
            waitForFinalDeliveryStatus:
                any(named: 'waitForFinalDeliveryStatus'),
            ttln: any(named: 'ttln'),
          ),
        ).called(1);
      }); // test sharePublicKeyIfRequired

      test('sharePublicKeyIfRequired - sendSshPublicKey = false', () async {
        when(() => mockParams.sendSshPublicKey).thenReturn(false);
        MockAtSshKeyPair identityKeyPair = MockAtSshKeyPair();

        when(() => identityKeyPair.publicKeyContents)
            .thenReturn(TestingKeyPair.public);

        verifyNever(notifyInvocation);

        await expectLater(
          stubbedSshnpdChannel.sharePublicKeyIfRequired(identityKeyPair),
          completes,
        );

        verifyNever(notifyInvocation);
      }); // test sharePublicKeyIfRequired - sendSshPublicKey = false

      test('sharePublicKeyIfRequired - identityKeyPair = null', () async {
        when(() => mockParams.sendSshPublicKey).thenReturn(true);

        verifyNever(notifyInvocation);

        await expectLater(
          stubbedSshnpdChannel.sharePublicKeyIfRequired(null),
          completes,
        );

        verifyNever(notifyInvocation);
      }); // test sharePublicKeyIfRequired - sendSshPublicKey = false

      test('sharePublicKeyIfRequired - malformed public key contents',
          () async {
        when(() => mockParams.sendSshPublicKey).thenReturn(true);
        MockAtSshKeyPair identityKeyPair = MockAtSshKeyPair();

        when(() => identityKeyPair.publicKeyContents)
            .thenReturn("I'm not an ssh public key!");

        verifyNever(notifyInvocation);

        await expectLater(
          stubbedSshnpdChannel.sharePublicKeyIfRequired(identityKeyPair),
          throwsA(isA<SshnpError>()),
        );

        verifyNever(notifyInvocation);
      }); // test sharePublicKeyIfRequired - malformed public key contents
    }); // group sharePublicKeyIfRequired

    group('Username resolution', () {
      test('resolveRemoteUsername - params.remoteUsername override', () async {
        when(() => mockParams.remoteUsername).thenReturn('myRemoteUsername');
        Future<String?> remoteUsername =
            stubbedSshnpdChannel.resolveRemoteUsername();
        await expectLater(remoteUsername, completes);
        expect(await remoteUsername, 'myRemoteUsername');
      }); // test resolveRemoteUsername

      test('resolveRemoteUsername - params.remoteUsername null', () async {
        when(() => mockParams.remoteUsername).thenReturn(null);
        when(() => mockParams.clientAtSign).thenReturn('@client');
        when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

        when(
          () => mockAtClient.get(
            any<AtKey>(
              that: predicate((AtKey key) => key.key.startsWith('username.')),
            ),
          ),
        ).thenAnswer((i) async => AtValue()..value = 'mySharedUsername');

        Future<String?> remoteUsername =
            stubbedSshnpdChannel.resolveRemoteUsername();
        await expectLater(remoteUsername, completes);
        expect(await remoteUsername, 'mySharedUsername');
      }); // test resolveRemoteUsername

      test('resolveTunnelUsername - params.tunnelUsername override', () async {
        when(() => mockParams.tunnelUsername).thenReturn('myTunnelUsername');
        Future<String?> tunnelUsername =
            stubbedSshnpdChannel.resolveTunnelUsername(remoteUsername: null);

        await expectLater(tunnelUsername, completes);
        expect(await tunnelUsername, 'myTunnelUsername');
      }); // test resolveTunnelUsername - params.tunnelUsername override

      test(
          'resolveTunnelUsername - params.tunnelUsername override, remoteUsername string',
          () async {
        when(() => mockParams.tunnelUsername).thenReturn('myTunnelUsername2');
        Future<String?> tunnelUsername = stubbedSshnpdChannel
            .resolveTunnelUsername(remoteUsername: 'remoteUsername');

        await expectLater(tunnelUsername, completes);
        expect(await tunnelUsername, 'myTunnelUsername2');
      }); // test resolveTunnelUsername - params.tunnelUsername override, remoteUsername string

      test('resolveTunnelUsername - params.tunnelUsername null', () async {
        when(() => mockParams.tunnelUsername).thenReturn(null);
        Future<String?> tunnelUsername = stubbedSshnpdChannel
            .resolveTunnelUsername(remoteUsername: 'fallbackUsername');

        await expectLater(tunnelUsername, completes);
        expect(await tunnelUsername, 'fallbackUsername');
      }); // test resolveTunnelUsername - params.tunnelUsername null

      test('resolveTunnelUsername - both usernames null', () async {
        when(() => mockParams.tunnelUsername).thenReturn(null);
        Future<String?> tunnelUsername =
            stubbedSshnpdChannel.resolveTunnelUsername(remoteUsername: null);

        await expectLater(tunnelUsername, completes);
        expect(await tunnelUsername, null);
      }); // resolveTunnelUsername - both usernames null
    }); // group Username resolution
    group('Device List', () {
      // TODO
    }); // group Device List
    test('getAtKeysRemote', () async {
      final remoteSecondary = MockRemoteSecondary();
      registerFallbackValue(ScanVerbBuilder());

      final sharedWith = 'mySharedWith';
      final sharedBy = 'mySharedBy';
      final regex = 'myRegex';
      final showHiddenKeys = true;

      when(() => mockAtClient.getRemoteSecondary()).thenReturn(remoteSecondary);
      when(
        () => remoteSecondary.executeVerb(
          any<VerbBuilder>(
            that: allOf(
              isA<ScanVerbBuilder>(),
              predicate(
                (ScanVerbBuilder builder) =>
                    builder.sharedWith == sharedWith &&
                    builder.sharedBy == sharedBy &&
                    builder.regex == regex &&
                    builder.showHiddenKeys == showHiddenKeys,
              ),
            ),
          ),
        ),
      ).thenAnswer((_) async => 'data:["phone.wavi@alice"]');

      verifyNever(() => mockAtClient.getRemoteSecondary());
      verifyNever(() => remoteSecondary.executeVerb(any()));

      Future<List<AtKey>> result = stubbedSshnpdChannel.getAtKeysRemote(
        sharedWith: sharedWith,
        sharedBy: sharedBy,
        regex: regex,
        showHiddenKeys: showHiddenKeys,
      );

      verifyInOrder([
        () => mockAtClient.getRemoteSecondary(),
        () => remoteSecondary.executeVerb(
              any<VerbBuilder>(
                that: allOf(
                  isA<ScanVerbBuilder>(),
                  predicate(
                    (ScanVerbBuilder builder) =>
                        builder.sharedWith == sharedWith &&
                        builder.sharedBy == sharedBy &&
                        builder.regex == regex &&
                        builder.showHiddenKeys == showHiddenKeys,
                  ),
                ),
              ),
            ),
      ]);

      await expectLater(result, completes);
      expect(
        await result,
        allOf(
          isA<List<AtKey>>(),
          hasLength(1),
          predicate(
            (List<AtKey> list) =>
                list.single.key == 'phone' &&
                list.single.namespace == 'wavi' &&
                list.single.sharedBy == '@alice',
          ),
        ),
      );

      verifyNever(() => mockAtClient.getRemoteSecondary());
      verifyNever(() => remoteSecondary.executeVerb(any()));

      expect(mockAtClient.getRemoteSecondary(), isA<RemoteSecondary>());
    }); // test getAtKeysRemote
  }); // group SshnpdChannel
}
