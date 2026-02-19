import 'dart:convert';
import 'package:at_client/at_client.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:noports_core/src/common/types.dart';

// Mock classes
class MockAtClient extends Mock implements AtClient {}

class MockAtNotification extends Mock implements AtNotification {}

class FakeAtKey extends Fake implements AtKey {}

class FakePutRequestOptions extends Fake implements PutRequestOptions {}

void main() {
  group('SshnpdImpl Session Mutex Tests', () {
    late MockAtClient mockAtClient;
    late SshnpdImpl sshnpd;

    setUpAll(() {
      // Register fallback values for mocktail
      registerFallbackValue(FakeAtKey());
      registerFallbackValue(FakePutRequestOptions());
    });

    setUp(() {
      mockAtClient = MockAtClient();

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
        deviceGroup: 'default',
        version: '1.0.0',
        permitOpen: ['*:*'],
        strict: false,
      );

      // Set up common mock behaviors
      when(() => mockAtClient.getCurrentAtSign()).thenReturn('@testdevice');
    });

    test(
      'extractSessionId should extract session ID from npt_request notification',
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
          'npt_request',
        );

        // Assert
        expect(result, equals(sessionId));
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

    test(
      'tryAcquireSessionMutex should return true when mutex is acquired successfully',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();
        final sessionId = 'test-session-789';
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
        when(() => mockNotification.from).thenReturn('@client');

        // Mock successful mutex acquisition
        when(
          () => mockAtClient.put(
            any(),
            'lock',
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        ).thenAnswer((_) async => true);

        // Act
        final result = await sshnpd.tryAcquireSessionMutex(
          mockNotification,
          'npt_request',
        );

        // Assert
        expect(result, isTrue);
        verify(
          () => mockAtClient.put(
            any(),
            'lock',
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        ).called(1);
      },
    );

    test(
      'tryAcquireSessionMutex should return false when mutex acquisition fails due to immutable key',
      () async {
        // Arrange
        final mockNotification = MockAtNotification();
        final sessionId = 'test-session-conflict';
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
        when(() => mockNotification.from).thenReturn('@client');

        // Mock failed mutex acquisition (immutable key already exists)
        when(
          () => mockAtClient.put(
            any(),
            'lock',
            putRequestOptions: any(named: 'putRequestOptions'),
          ),
        ).thenThrow(Exception('Cannot update immutable key'));

        // Act
        final result = await sshnpd.tryAcquireSessionMutex(
          mockNotification,
          'npt_request',
        );

        // Assert
        expect(result, isFalse);
      },
    );

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
          'npt_request',
        );

        // Assert
        expect(
          result,
          isTrue,
        ); // Should proceed without mutex for backward compatibility
      },
    );
  });
}
