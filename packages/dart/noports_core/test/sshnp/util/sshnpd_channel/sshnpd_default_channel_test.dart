import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

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
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');
      when(() => mockParams.authenticateDeviceToRvd).thenReturn(true);
      when(() => mockParams.authenticateClientToRvd).thenReturn(true);
      when(() => mockParams.encryptRvdTraffic).thenReturn(true);
      when(() => mockParams.sendSshPublicKey).thenReturn(false);
      when(subscribeInvocation)
          .thenAnswer((_) => notificationStreamController.stream);
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
          regex: '$sessionId.$namespace@sshnpd',
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

    test('handleSshnpdPayload - no public key cache', () async {
      // Create an AtChops instance for testing
      AtEncryptionKeyPair encryptionKeyPair =
          AtChopsUtil.generateAtEncryptionKeyPair();

      AtChops atChops = AtChopsImpl(
        AtChopsKeys.create(encryptionKeyPair, null),
      );

      when(() => mockAtClient.atChops).thenReturn(atChops);
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = signAndWrapAndJsonEncode(mockAtClient, payload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // manually disable public key cache
      stubbedSshnpdDefaultChannel.fs = null;

      // Return the testing encryption public key when it's requested
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate(
              (AtKey key) => key.key.contains('cached_pks'),
            ),
          ),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );

      Future<SshnpdAck> ack =
          stubbedSshnpdDefaultChannel.handleSshnpdPayload(notification);

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledged);
      expect(stubbedSshnpdDefaultChannel.ephemeralPrivateKey,
          TestingKeyPair.private);
    }); // test handleSshnpdPayload - no public key cache

    test('handleSshnpdPayload - with in-memory public key cache', () async {
      // Create an AtChops instance for testing
      AtEncryptionKeyPair encryptionKeyPair =
          AtChopsUtil.generateAtEncryptionKeyPair();

      AtChops atChops = AtChopsImpl(
        AtChopsKeys.create(encryptionKeyPair, null),
      );

      when(() => mockAtClient.atChops).thenReturn(atChops);
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = signAndWrapAndJsonEncode(mockAtClient, payload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // manually disable public key cache
      FileSystem fs = MemoryFileSystem();
      stubbedSshnpdDefaultChannel.fs = fs;

      String? homeDirPath = getHomeDirectory();

      if (homeDirPath == null) {
        stderr.writeln('Could not complete test on the current platform.');
        return;
      }

      File cacheFile = fs.file(path.join(
        homeDirPath,
        '.atsign',
        'sshnp',
        'cached_pks',
        mockParams.sshnpdAtSign.substring(1),
      ));

      await cacheFile.create(recursive: true);
      await cacheFile.writeAsString(encryptionKeyPair.atPublicKey.publicKey);

      Future<SshnpdAck> ack =
          stubbedSshnpdDefaultChannel.handleSshnpdPayload(notification);

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledged);
      expect(stubbedSshnpdDefaultChannel.ephemeralPrivateKey,
          TestingKeyPair.private);
    }); // test handleSshnpdPayload - with in-memory public key cache

    test('handleSshnpdPayload - bad signature', () async {
      // Create an AtChops instance for testing
      AtEncryptionKeyPair encryptionKeyPair =
          AtChopsUtil.generateAtEncryptionKeyPair();

      AtChops atChops = AtChopsImpl(
        AtChopsKeys.create(encryptionKeyPair, null),
      );

      when(() => mockAtClient.atChops).thenReturn(atChops);
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@client');
      when(() => mockParams.sshnpdAtSign).thenReturn('@sshnpd');

      Map<String, dynamic> payload = {
        'sessionId': sessionId,
        'ephemeralPrivateKey': TestingKeyPair.private,
      };

      String signedPayload = signAndWrapAndJsonEncode(mockAtClient, payload);

      Map<String, dynamic> workingPayload = jsonDecode(signedPayload);
      workingPayload['signature'] = 'askdlfjsdklfjsldkfj';

      signedPayload = jsonEncode(workingPayload);

      AtNotification notification = AtNotification.empty()
        ..value = signedPayload;

      // manually disable public key cache
      stubbedSshnpdDefaultChannel.fs = null;

      // Return the testing encryption public key when it's requested
      when(
        () => mockAtClient.get(
          any<AtKey>(
            that: predicate(
              (AtKey key) => key.key.contains('cached_pks'),
            ),
          ),
        ),
      ).thenAnswer(
        (_) async => AtValue()..value = encryptionKeyPair.atPublicKey.publicKey,
      );

      Future<SshnpdAck> ack =
          stubbedSshnpdDefaultChannel.handleSshnpdPayload(notification);

      await expectLater(ack, completes);
      expect(await ack, SshnpdAck.acknowledgedWithErrors);
      expect(stubbedSshnpdDefaultChannel.ephemeralPrivateKey, null);
    }); // test handleSshnpdPayload - bad signature
  }); // group SshnpDefaultChannel
}
