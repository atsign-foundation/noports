import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:at_commons/at_builders.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:uuid/uuid.dart';

// Mock classes
class MockAtClient extends Mock implements AtClient {}

class MockRemoteSecondary extends Mock implements RemoteSecondary {}

class MockAtNotification extends Mock implements AtNotification {}

class FakeAtKey extends Fake implements AtKey {}

class FakePutRequestOptions extends Fake implements PutRequestOptions {}

class FakeVerbBuilder extends Fake implements VerbBuilder {}

void main() {
  group('SshnpdImpl Session Mutex Tests', () {
    late MockAtClient mockAtClient;
    late MockRemoteSecondary remote;
    late SshnpdImpl sshnpd;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(FakeAtKey());
      registerFallbackValue(FakePutRequestOptions());
      registerFallbackValue(FakeVerbBuilder());
    });

    setUp(() {
      mockAtClient = MockAtClient();
      remote = MockRemoteSecondary();
      when(() => mockAtClient.getRemoteSecondary()).thenReturn(remote);
      // The constructor composes the daemon's device info, which names the
      // `_apsk` record of the atSign the client runs as.
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@device');

      // Create SshnpdImpl instance with minimal required parameters
      sshnpd = SshnpdImpl(
        atClient: mockAtClient,
        username: 'testuser',
        homeDirectory: '/home/testuser',
        device: 'testdevice',
        managerAtsigns: ['@manager'],
        policyManagerAtsign: null,
        sshClient: SupportedSshClient.openssh,
        makeDeviceInfoVisible: false,
        addSshPublicKeys: false,
        localSshdPort: 22,
        sshPublicKeyPermissions: '',
        ephemeralPermissions: '',
        sshAlgorithm: SupportedSshAlgorithm.rsa,
        deviceGroup: 'default',
        version: '1.0.0',
        permitOpen: ['*:*'],
        strict: false,
        clientKeyCheckInterval: Duration.zero,
        requireEnrollmentSignature: false,
      );

      // Set up common mock behaviors
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@testdevice');
    });

    test(
      'extractSessionId should extract session ID from ssh_request notification',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();
        final sessionId = 'test-session-123';
        final payload = {
          'sessionId': sessionId,
          'host': 'example.com',
          'port': 22,
          'direct': true,
        };
        final envelope = {
          'payload': payload,
          'signature': 'test-signature',
          'hashingAlgo': 'sha256',
          'signingAlgo': 'rsa2048',
        };

        when(() => mockNotification.value).thenReturn(jsonEncode(envelope));

        // Act
        final result = await sshnpd.extractSessionId(
          mockNotification,
          'ssh_request',
        );

        // Assert
        expect(result, equals(sessionId));
      },
    );

    test(
      'extractSessionId should extract session ID from legacy sshd notification with session ID',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();
        final sessionId = 'legacy-session-456';
        final legacyPayload = '8080 22 testuser example.com $sessionId';

        when(() => mockNotification.value).thenReturn(legacyPayload);

        // Act
        final result = await sshnpd.extractSessionId(mockNotification, 'sshd');

        // Assert
        expect(result, equals(sessionId));
      },
    );

    test(
      'extractSessionId should generate session ID for legacy sshd notification without session ID',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();
        final notificationId = 'notification-123';
        final legacyPayload = '8080 22 testuser example.com'; // No session ID

        when(() => mockNotification.value).thenReturn(legacyPayload);
        when(() => mockNotification.id).thenReturn(notificationId);

        // Act
        final result = await sshnpd.extractSessionId(mockNotification, 'sshd');

        // Assert
        expect(result, equals('legacy_$notificationId'));
      },
    );

    test(
      'extractSessionId should return null for non-session-based notifications',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();

        when(() => mockNotification.value).thenReturn('test-value');

        // Act
        final result = await sshnpd.extractSessionId(mockNotification, 'ping');

        // Assert
        expect(result, isNull);
      },
    );

    MockAtNotification nptRequest(String sessionId) {
      final n = MockAtNotification();
      when(() => n.value).thenReturn(jsonEncode({
        'payload': {'sessionId': sessionId, 'direct': true},
        'signature': 'test-signature',
        'hashingAlgo': 'sha256',
        'signingAlgo': 'rsa2048',
      }));
      when(() => n.from).thenReturn('@client');
      return n;
    }

    group('Given no lock for the session', () {
      test(
          'when sshnpd receives an npt_request, then it takes the lock on the'
          ' atServer as an immutable record with a 30 s ttl and no commit,'
          ' and handles the request', () async {
        final sessionId = Uuid().v4();
        when(() => remote.executeVerb(any())).thenAnswer((_) async => '-1');

        expect(
          await sshnpd.tryAcquireSessionMutex(
              nptRequest(sessionId), 'npt_request'),
          isTrue,
        );
        final lock = verify(() => remote.executeVerb(captureAny()))
            .captured
            .single as UpdateVerbBuilder;
        expect(lock.atKey.toString(),
            '$sessionId.session_mutexes.sshnp@testdevice');
        expect(lock.atKey.metadata.immutable, isTrue);
        expect(lock.atKey.metadata.ttl, 30000);
        expect(lock.noCommit, isTrue);
        verifyNever(() => mockAtClient.put(any(), any(),
            putRequestOptions: any(named: 'putRequestOptions')));
      });
    });

    group('Given another sshnpd instance holds the session lock', () {
      test('when sshnpd receives the request, then it does not handle it',
          () async {
        when(() => remote.executeVerb(any()))
            .thenThrow(AtException('Immutable records may not be updated'));

        expect(
          await sshnpd.tryAcquireSessionMutex(
              nptRequest(Uuid().v4()), 'npt_request'),
          isFalse,
        );
      });
    });

    group('Given the session lock fails for another reason', () {
      test(
          'when sshnpd receives the request, then it handles it anyway and'
          ' logs the failure at warning', () async {
        when(() => remote.executeVerb(any()))
            .thenThrow(AtTimeoutException('no answer from the atServer'));
        sshnpd.logger.logger.level = Level.ALL;
        final records = <LogRecord>[];
        final sub = sshnpd.logger.logger.onRecord.listen(records.add);
        addTearDown(sub.cancel);

        expect(
          await sshnpd.tryAcquireSessionMutex(
              nptRequest(Uuid().v4()), 'npt_request'),
          isTrue,
        );
        expect(
          records.where((r) =>
              r.level == Level.WARNING &&
              r.message.contains('without a session mutex')),
          hasLength(1),
        );
      });
    });

    test(
      'tryAcquireSessionMutex should return true when session ID extraction fails',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();

        when(() => mockNotification.value).thenReturn('invalid-json');
        when(() => mockNotification.from).thenReturn('@client');

        // Act
        final result = await sshnpd.tryAcquireSessionMutex(
          mockNotification,
          'ssh_request',
        );

        // Assert
        expect(
          result,
          isTrue,
        ); // Should proceed without mutex for backward compatibility
      },
    );

    group('clientRequestNotificationHandler sessionId gate', () {
      MockAtNotification request(String messageType, String value) {
        final n = MockAtNotification();
        when(() => n.id).thenReturn('notification-1');
        when(() => n.from).thenReturn('@manager');
        when(() => n.to).thenReturn('@testdevice');
        when(
          () => n.key,
        ).thenReturn('@testdevice:$messageType.testdevice.sshnp@manager');
        when(() => n.value).thenReturn(value);
        return n;
      }

      String envelope(Map<String, dynamic> payload) => jsonEncode({
        'payload': payload,
        'signature': 'test-signature',
        'hashingAlgo': 'sha256',
        'signingAlgo': 'rsa2048',
      });

      late int locks;

      Future<int> mutexLocks(AtNotification n) async {
        locks = 0;
        await sshnpd.clientRequestNotificationHandler(n);
        return locks;
      }

      const invalidSessionIds = [
        '',
        'ssh',
        'abc\nssh-ed25519 AAAAattackerKey attacker',
        '6ba7b810-9dad-11d1-80b4-00c04fd430c8\n',
      ];

      setUp(() {
        // NOTE: a granted mutex would dispatch the request and start a
        // session, so every request that reaches it is refused there.
        when(() => remote.executeVerb(any())).thenAnswer((_) async {
          locks++;
          throw AtException('Immutable records may not be updated');
        });
      });

      for (final messageType in ['ssh_request', 'npt_request']) {
        test('$messageType with a UUID sessionId reaches the mutex', () async {
          final n = request(
            messageType,
            envelope({'sessionId': Uuid().v4(), 'direct': true}),
          );
          expect(await mutexLocks(n), 1);
        });

        test('$messageType with a sessionId which is not a UUID is refused'
            ' before the mutex', () async {
          for (final sessionId in invalidSessionIds) {
            final n = request(
              messageType,
              envelope({'sessionId': sessionId, 'direct': true}),
            );
            expect(await mutexLocks(n), 0, reason: 'sessionId "$sessionId"');
          }
        });

        test('hasValidSessionId accepts a $messageType with a UUID', () {
          final n = request(messageType, envelope({'sessionId': Uuid().v4()}));
          expect(sshnpd.hasValidSessionId(n, messageType), isTrue);
        });

        test('hasValidSessionId refuses a $messageType whose sessionId is'
            ' missing, not a String, or not a UUID', () {
          for (final value in [
            envelope({'direct': true}),
            envelope({'sessionId': null}),
            envelope({'sessionId': 42}),
            envelope({'sessionId': 'ssh'}),
            jsonEncode({'payload': 'not a map'}),
            'invalid-json',
          ]) {
            final n = request(messageType, value);
            expect(
              sshnpd.hasValidSessionId(n, messageType),
              isFalse,
              reason: 'accepted $value',
            );
          }
        });
      }

      test('hasValidSessionId refuses a legacy sshd with no value', () {
        final n = MockAtNotification();
        when(() => n.value).thenReturn(null);
        expect(sshnpd.hasValidSessionId(n, 'sshd'), isFalse);
      });

      test('legacy sshd with a UUID sessionId reaches the mutex', () async {
        final n = request(
          'sshd',
          '8080 22 testuser example.com ${Uuid().v4()}',
        );
        expect(await mutexLocks(n), 1);
      });

      test('legacy sshd without a sessionId reaches the mutex', () async {
        final n = request('sshd', '8080 22 testuser example.com');
        expect(await mutexLocks(n), 1);
      });

      test('legacy sshd with a sessionId which is not a UUID is refused'
          ' before the mutex', () async {
        final n = request('sshd', '8080 22 testuser example.com ssh');
        expect(await mutexLocks(n), 0);
      });
    });
  });
}
