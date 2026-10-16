import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import '../../sshnp_core_constants.dart';
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
    late StubbedSshnpdDefaultChannel stubbedSshnpdDefaultChannel;

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

      stubbedSshnpdDefaultChannel = StubbedSshnpdDefaultChannel(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        namespace: namespace,
        subscribe: subscribeStub.call,
      );

      registerFallbackValue(AtKey());
    });

    test('public API ', () {
      expect(stubbedSshnpdDefaultChannel.ephemeralPrivateKey, isNull);
      stubbedSshnpdDefaultChannel.ephemeralPrivateKey = TestingKeyPair.private;
      expect(
        stubbedSshnpdDefaultChannel.ephemeralPrivateKey,
        TestingKeyPair.private,
      );
    }); // test public API

    whenInitialization() {
      when(() => mockParams.clientAtSign).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.sendSshPublicKey).thenReturn(false);
      when(
        subscribeInvocation,
      ).thenAnswer((_) => notificationStreamController.stream);
    }

    // Same test as on the base class
    test('Initialization', () async {
      whenInitialization();
      expect(stubbedSshnpdDefaultChannel.sshnpdAck, SshnpdAck.notAcknowledged);
      expect(stubbedSshnpdDefaultChannel.initializeStarted, false);

      verifyNever(subscribeInvocation);

      // it's okay to call this directly for testing purposes
      await expectLater(stubbedSshnpdDefaultChannel.initialize(), completes);

      verify(
        () => subscribeStub(
          regex: '$sessionId.$namespace@sshnpd\$',
          shouldDecrypt: true,
        ),
      ).called(1);
    }); // test Initialization

    test('Initialization completes', () async {
      whenInitialization();
      await expectLater(
        stubbedSshnpdDefaultChannel.callInitialization(),
        completes,
      );
      await expectLater(stubbedSshnpdDefaultChannel.initialized, completes);
    }); // test Initialization completes

    test('handleSshnpdPayload - fetches public key from remote', () async {
      RsaKeyPair encryptionKeyPair = RsaKeyPair.generate();
      stubEncryptionKeys(mockAtClient, encryptionKeyPair, atSign: '@client');
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = await signAndWrapAndJsonEncode(mockAtClient, payload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // Return the testing encryption public key when it's requested
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate((AtKey key) => key.key.contains('publickey')),
          ),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );

      Future<SshnpdAck> ack = stubbedSshnpdDefaultChannel.handleSshnpdPayload(
        notification,
      );

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledged);
      expect(
        stubbedSshnpdDefaultChannel.ephemeralPrivateKey,
        TestingKeyPair.private,
      );
    }); // test handleSshnpdPayload - fetches public key from remote

    test('handleSshnpdPayload - successful payload handling', () async {
      RsaKeyPair encryptionKeyPair = RsaKeyPair.generate();
      stubEncryptionKeys(mockAtClient, encryptionKeyPair, atSign: '@client');
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = await signAndWrapAndJsonEncode(mockAtClient, payload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // Return the testing encryption public key when it's requested
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate((AtKey key) => key.key.contains('publickey')),
          ),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );

      Future<SshnpdAck> ack = stubbedSshnpdDefaultChannel.handleSshnpdPayload(
        notification,
      );

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledged);
      expect(
        stubbedSshnpdDefaultChannel.ephemeralPrivateKey,
        TestingKeyPair.private,
      );
    }); // test handleSshnpdPayload - successful payload handling

    test('handleSshnpdPayload - rejects invalid signature', () async {
      RsaKeyPair encryptionKeyPair = RsaKeyPair.generate();
      stubEncryptionKeys(mockAtClient, encryptionKeyPair, atSign: '@client');
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = await signAndWrapAndJsonEncode(mockAtClient, payload);

      Map<String, dynamic> workingPayload = jsonDecode(signedPayload);
      workingPayload['signature'] = 'askdlfjsdklfjsldkfj';

      signedPayload = jsonEncode(workingPayload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // Return the testing encryption public key when it's requested
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate((AtKey key) => key.key.contains('publickey')),
          ),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );

      Future<SshnpdAck> ack = stubbedSshnpdDefaultChannel.handleSshnpdPayload(
        notification,
      );

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledgedWithErrors);
      expect(stubbedSshnpdDefaultChannel.ephemeralPrivateKey, null);
    }); // test handleSshnpdPayload - rejects invalid signature
  }); // group SshnpDefaultChannel

  group("Given sshnp is waiting for its daemon's response, logging at every"
      ' level, and the response carries an ephemeral private key', () {
    late _CapturingLoggingHandler handler;
    late MockAtClient mockAtClient;
    late StubbedSshnpdDefaultChannel channel;
    late String sessionId;

    setUp(() {
      handler = _CapturingLoggingHandler();
      final previousHandler = AtSignLogger.defaultLoggingHandler;
      AtSignLogger.defaultLoggingHandler = handler;
      addTearDown(() => AtSignLogger.defaultLoggingHandler = previousHandler);

      registerFallbackValue(AtKey());
      mockAtClient = MockAtClient();
      final mockParams = MockSshnpParams();
      sessionId = Uuid().v4();
      final encryptionKeyPair = RsaKeyPair.generate();
      stubEncryptionKeys(mockAtClient, encryptionKeyPair, atSign: '@client');
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate((AtKey key) => key.key.contains('publickey')),
          ),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );
      when(() => mockParams.verbose).thenReturn(true);
      when(() => mockParams.device).thenReturn('myDevice');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      channel = StubbedSshnpdDefaultChannel(
        atClient: mockAtClient,
        params: mockParams,
        sessionId: sessionId,
        namespace: 'myDevice.sshnp',
      )..logger.level = 'all';
    });

    Future<Map<String, dynamic>> signedResponse() async => jsonDecode(
      await signAndWrapAndJsonEncode(mockAtClient, {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      }),
    );

    /// Hands [value] to the channel as the daemon's response notification,
    /// returning the acknowledgement the channel records for it.
    Future<SshnpdAck> receiveValue(String value) async {
      await channel.handleSshnpdResponses(AtNotification.empty()..value = value);
      return channel.sshnpdAck;
    }

    Future<SshnpdAck> receive(Map<String, dynamic> envelope) =>
        receiveValue(jsonEncode(envelope));

    List<String> messages() => handler.records.map((r) => r.message).toList();

    void expectNoRecordHoldsTheKey() => expect(
      _recordsHoldingKey(handler.records, TestingKeyPair.private),
      isEmpty,
      reason: 'no log record may hold any line of the private key',
    );

    test('when the response is signed by the daemon, then sshnp keeps the key'
        ' for the session and acknowledges the response, and no log record'
        ' contains the key', () async {
      final ack = await receive(await signedResponse());

      expectNoRecordHoldsTheKey();
      expect(ack, SshnpdAck.acknowledged);
      expect(channel.ephemeralPrivateKey, TestingKeyPair.private);
      expect(
        messages(),
        contains(contains('Verified signature of msg from @sshnpd')),
        reason: 'the capture sees the channel logging at info',
      );
    });

    test("when the response's signature doesn't verify, then sshnp"
        " acknowledges with errors and logs that the signature from the daemon's"
        " atSign didn't verify, and no log record contains the key", () async {
      final envelope = await signedResponse()
        ..['signature'] = 'not-the-daemons-signature';

      final ack = await receive(envelope);

      expectNoRecordHoldsTheKey();
      expect(ack, SshnpdAck.acknowledgedWithErrors);
      expect(channel.ephemeralPrivateKey, isNull);
      expect(
        messages(),
        contains('Failed to verify signature of msg from @sshnpd'),
        reason: "the log says whose signature didn't verify",
      );
    });

    test("when the response can't be read, as when its signature is missing,"
        " then sshnp acknowledges with errors and logs that it couldn't read the"
        " response from the daemon's atSign, giving the error's type, and no log"
        ' record contains the key', () async {
      final envelope = await signedResponse()..remove('signature');

      final ack = await receive(envelope);

      expectNoRecordHoldsTheKey();
      expect(ack, SshnpdAck.acknowledgedWithErrors);
      expect(channel.ephemeralPrivateKey, isNull);
      expect(
        messages(),
        contains('Failed to read the response from @sshnpd: ArgumentError'),
        reason: "the log names the daemon's atSign and the error's type",
      );
    });

    test('when the response is cut short partway through the key, then sshnp'
        " acknowledges with errors and logs that it couldn't read the response"
        " from the daemon's atSign, giving the error's type, and no log record"
        ' contains any of the key', () async {
      final whole = jsonEncode(await signedResponse());
      final secondLine = TestingKeyPair.private.split('\n')[2];
      final cut = whole.substring(
        0,
        whole.indexOf(secondLine) + secondLine.length,
      );

      final ack = await receiveValue(cut);

      expectNoRecordHoldsTheKey();
      expect(ack, SshnpdAck.acknowledgedWithErrors);
      expect(channel.ephemeralPrivateKey, isNull);
      expect(
        messages(),
        contains('Failed to read the response from @sshnpd: FormatException'),
        reason: "the log names the daemon's atSign and the error's type",
      );
    });
  });
}

/// Collects log records instead of printing them.
class _CapturingLoggingHandler implements LoggingHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void call(LogRecord record) => records.add(record);
}

/// The text of each of [records] holding a line of [pem]'s body. Matching by
/// line finds the key whether it was logged as it is or JSON-encoded.
List<String> _recordsHoldingKey(Iterable<LogRecord> records, String pem) {
  final lines = pem
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.length >= 16 && !line.startsWith('-----'))
      .toList();
  if (lines.isEmpty) {
    throw ArgumentError.value(pem, 'pem', 'has no body lines to look for');
  }
  return [
    for (final record in records)
      for (final text in [record.message, '${record.error ?? ''}'])
        if (lines.any(text.contains)) '${record.loggerName}: $text',
  ];
}
