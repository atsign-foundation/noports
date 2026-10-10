import 'dart:convert';
import 'dart:io';

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
    const sessionId = 'the-session';

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
  });
}
