import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/srvd.dart' show Srvd;
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;
import 'package:noports_core/src/srvd/session_info.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// Logs at INFO, as srvd does under `--verbose`, and treats every atSign as
/// one with an atServer.
class _Srvd extends SrvdImpl {
  _Srvd()
      : super(
          atClient: MockAtClient(),
          atSign: '@relay'.toAtsign(),
          homeDirectory: Directory.current.path,
          atKeysFilePath: Directory.current.path,
          managerAtsign: 'open',
          ipAddress: '127.0.0.1',
          logTraffic: false,
          verbose: false,
          bind443: false,
          localBindPort443: 443,
          relayAuthDetectWindowMs: defaultRelayAuthDetectWindowMs,
          signingKeyCheckInterval: Duration.zero,
        ) {
    logger.logger.level = Level.INFO;
  }

  @override
  Future<bool> validAtsign(String? atSign) async => true;
}

class _CapturingLoggingHandler implements LoggingHandler {
  final List<LogRecord> records = <LogRecord>[];

  @override
  void call(LogRecord record) => records.add(record);
}

void main() {
  group('Given a relay with a session from client @alice to daemon @bob', () {
    const sessionId = '5a1f7d0e-3b2c-4d6e-8f90-1a2b3c4d5e6f';

    final logs = _CapturingLoggingHandler();
    late LoggingHandler previousHandler;

    setUpAll(() {
      previousHandler = AtSignLogger.defaultLoggingHandler;
      AtSignLogger.defaultLoggingHandler = logs;
    });

    tearDownAll(() => AtSignLogger.defaultLoggingHandler = previousHandler);

    setUp(logs.records.clear);

    _Srvd relay() => _Srvd()
      ..sessions[sessionId] = SessionInfo(
        params: SrvdSessionParams(
          sessionId: sessionId,
          atSignA: '@alice',
          atSignB: '@bob',
          rvdNonce: 'rvd nonce',
          only443: false,
          multipleAcksOk: false,
          preFetch: const [],
          sendJsonResponse: true,
        ),
        connector: null,
      );

    AtNotification logging(String from, {required String eventsAtSign}) =>
        AtNotification(
          'logging-id',
          '@relay:logging.$sessionId.sessions.${Srvd.namespace}$from',
          from,
          '@relay',
          1,
          'key',
          true,
          value: jsonEncode({
            'atSign': eventsAtSign,
            'topic': 'abc.events.logging.sshnp',
            'ttln': 60000,
          }),
        );

    String? eventsAtSignOf(_Srvd srvd) =>
        srvd.sessions[sessionId]!.eventLoggingConfig?.atSign;

    test(
        "when @bob sends the session's logging config, then the relay takes it",
        () async {
      final srvd = relay();

      await srvd.notificationHandler(logging('@bob', eventsAtSign: '@events'));

      expect(eventsAtSignOf(srvd), '@events');
    });

    test(
        'when @alice sends a logging config, then the relay ignores it and logs'
        ' a warning', () async {
      final srvd = relay();

      await srvd
          .notificationHandler(logging('@alice', eventsAtSign: '@carol'));

      expect(eventsAtSignOf(srvd), isNull);
      expect(
        logs.records.where(
          (r) => r.level == Level.WARNING && r.message.contains('@alice'),
        ),
        isNotEmpty,
        reason: 'the ignored config is logged at warning, naming its sender',
      );
    });

    test(
        "when @alice sends a logging config and then @bob sends one, then the"
        " relay takes @bob's", () async {
      final srvd = relay();

      await srvd
          .notificationHandler(logging('@alice', eventsAtSign: '@carol'));
      await srvd.notificationHandler(logging('@bob', eventsAtSign: '@events'));

      expect(eventsAtSignOf(srvd), '@events');
    });

    test(
        'when @bob sends the logging config naming the session id in upper'
        ' case, then the relay takes it', () async {
      final srvd = relay();

      await srvd.notificationHandler(AtNotification(
        'logging-id',
        '@relay:logging.${sessionId.toUpperCase()}.sessions'
            '.${Srvd.namespace}@bob',
        '@bob',
        '@relay',
        1,
        'key',
        true,
        value: jsonEncode({
          'atSign': '@events',
          'topic': 'abc.events.logging.sshnp',
          'ttln': 60000,
        }),
      ));

      expect(sessionId.toUpperCase(), isNot(sessionId),
          reason: 'the id has letters to fold');
      expect(eventsAtSignOf(srvd), '@events');
    });

    test('A message about a session whose id is not a UUID is ignored',
        () async {
      const notAUuid = 'no-uuid-zz';
      final worker = ReceivePort();
      addTearDown(worker.close);
      final received = <Object?>[];
      worker.listen(received.add);
      final live = SessionInfo(
        params: SrvdSessionParams(
          sessionId: notAUuid,
          atSignA: '@alice',
          atSignB: '@bob',
          rvdNonce: 'rvd nonce',
          only443: false,
          multipleAcksOk: false,
          preFetch: const [],
          sendJsonResponse: true,
        ),
        connector: null,
        toWorker: worker.sendPort,
      );
      final srvd = relay()
        ..sessions[notAUuid] = live
        ..logger.level = 'all';

      await srvd.notificationHandler(AtNotification(
        'logging-id',
        '@relay:logging.$notAUuid.sessions.${Srvd.namespace}@bob',
        '@bob',
        '@relay',
        1,
        'key',
        true,
        value: jsonEncode({
          'atSign': '@events',
          'topic': 'abc.events.logging.sshnp',
          'ttln': 60000,
        }),
      ));
      await srvd.handleAuthModes(AtNotification(
        'auth-modes-id',
        '@relay:local.auth_modes.${Srvd.namespace}@alice',
        '@alice',
        '@relay',
        1,
        'key',
        true,
        value: jsonEncode({
          'sessionId': notAUuid,
          'rvdNonce': 'rvd nonce',
          'sideA': 'escr',
          'sideB': 'escr',
        }),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(live.eventLoggingConfig, isNull,
          reason: 'the logging config was not taken');
      expect(received, isEmpty, reason: 'nothing was sent to its worker');
      for (final String line in [
        'about a session whose id is not a UUID',
        'names no session by a UUID',
      ]) {
        expect(
          logs.records.where((r) => r.message.contains(line)),
          hasLength(1),
          reason: 'the relay says it ignored each message, the control that'
              ' these log lines are being read',
        );
      }
      expect(
        logs.records.where((r) =>
            r.message.contains(notAUuid) &&
            !r.message.contains('logging.$notAUuid.sessions.')),
        isEmpty,
        reason: "the id is repeated in no line beyond the notification's own"
            ' key, which srvd logs for every notification',
      );
    });
  });
}
