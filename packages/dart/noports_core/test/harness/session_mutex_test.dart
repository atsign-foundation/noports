import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:noports_core/src/sshnpd/sshnpd_impl.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'noports_harness.dart';

void main() {
  group('Given sshnpd on the fake atServer', () {
    late NoPortsHarness harness;
    late SshnpdImpl daemon;
    late AtClient otherInstance;

    setUp(() async {
      harness = NoPortsHarness.create();
      daemon = await harness.startDaemon(permitOpen: ['localhost:*']);
      otherInstance = await harness.openClient(
        NoPortsHarness.daemonAtSign,
        namespace: DefaultArgs.namespace,
        enrollment: harness.server[NoPortsHarness.daemonAtSign].enroll(
          appName: 'noports',
          deviceName: 'another_instance',
          namespaces: const {'sshnp': 'rw'},
        ),
      );
    });

    AtKey lockFor(String sessionId) => AtKey.fromString(
      '$sessionId.session_mutexes.${DefaultArgs.namespace}'
      '${NoPortsHarness.daemonAtSign}',
    );

    AtNotification nptRequest(String sessionId) => AtNotification(
      'notification-1',
      '${NoPortsHarness.daemonAtSign}:npt_request.${NoPortsHarness.device}'
          '.sshnp${NoPortsHarness.clientAtSign}',
      NoPortsHarness.clientAtSign,
      NoPortsHarness.daemonAtSign,
      DateTime.now().millisecondsSinceEpoch,
      'key',
      true,
      value: jsonEncode({
        'payload': {'sessionId': sessionId, 'direct': true},
        'signature': 'test-signature',
        'hashingAlgo': 'sha256',
        'signingAlgo': 'rsa2048',
      }),
    );

    /// Takes the lock the way sshnpd did before at_client's server mutex.
    Future<void> olderInstanceLocks(String sessionId) => otherInstance.put(
      lockFor(sessionId)
        ..metadata = (Metadata()
          ..immutable = true
          ..ttl = 30000),
      'lock',
      putRequestOptions: PutRequestOptions()
        ..shouldEncrypt = false
        ..useRemoteAtServer = true,
    );

    test('when sshnpd takes a session lock, then the atServer holds an'
        ' immutable record with a 30 s ttl, written with :nc', () async {
      final sessionId = Uuid().v4();

      expect(
        await daemon.tryAcquireSessionMutex(
          nptRequest(sessionId),
          'npt_request',
        ),
        isTrue,
      );

      final key = lockFor(sessionId).toString();
      final record = harness.server[NoPortsHarness.daemonAtSign].recordAt(key);
      expect(record, isNotNull);
      expect(record!.metadata['immutable'], isTrue);
      expect(record.metadata['ttl'], 30000);
      expect(
        harness.server.connections
            .expand((c) => c.commands)
            .where((c) => c.startsWith('update:nc:') && c.contains(key)),
        hasLength(1),
      );
    });

    test('when another instance already holds the session lock, then sshnpd'
        ' does not handle the request', () async {
      final sessionId = Uuid().v4();
      expect(
        await otherInstance.tryAcquireServerMutex(
          lockFor(sessionId),
          ttl: DefaultArgs.sessionMutexTtl,
        ),
        isNotNull,
      );

      expect(
        await daemon.tryAcquireSessionMutex(
          nptRequest(sessionId),
          'npt_request',
        ),
        isFalse,
      );
    });

    test('when an older instance already holds the session lock as a plain'
        ' immutable record, then sshnpd does not handle the request', () async {
      final sessionId = Uuid().v4();
      await olderInstanceLocks(sessionId);

      expect(
        await daemon.tryAcquireSessionMutex(
          nptRequest(sessionId),
          'npt_request',
        ),
        isFalse,
      );
    });

    test('when sshnpd holds the session lock, then an older instance taking'
        ' it the old way is refused as an immutable record', () async {
      final sessionId = Uuid().v4();
      expect(
        await daemon.tryAcquireSessionMutex(
          nptRequest(sessionId),
          'npt_request',
        ),
        isTrue,
      );

      await expectLater(
        olderInstanceLocks(sessionId),
        throwsA(
          predicate(
            (e) => e.toString().toLowerCase().contains('immutable'),
            "an error naming the immutable record, which the older"
            " instance reads as 'held'",
          ),
        ),
      );
    });
  });
}
