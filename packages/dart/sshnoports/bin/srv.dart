import 'dart:async';
import 'dart:io';

import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;
import 'package:args/args.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/srv.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/src/print_version.dart';

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'INFO';
  var fileLoggingHandler = TmpFileLoggingHandler();
  AtSignLogger.defaultLoggingHandler = fileLoggingHandler;

  AtSignLogger logger = AtSignLogger(' srv.main ');

  final ArgParser parser = ArgParser()
    ..addOption('host', abbr: 'h', mandatory: true, help: 'rvd host')
    ..addOption('port', abbr: 'p', mandatory: true, help: 'rvd port')
    ..addOption('local-port',
        defaultsTo: '22',
        help: 'On the daemon side, this is the local port to connect to.'
            ' On the client side this is the local port which the srv will bind'
            ' to so that client-side programs can create sockets to it.')
    ..addOption('heartbeat',
        defaultsTo: '1800',
        help: 'How frequently to send heartbeats on the connection\'s'
            ' control channel. Defaults to 30 minutes (1800 seconds)')
    ..addOption('timeout',
        defaultsTo: '60',
        help: 'How long to keep the SocketConnector open'
            ' if there have been no connections')
    ..addFlag('bind-local-port',
        defaultsTo: false, negatable: false, help: 'Client side flag.')
    ..addOption('local-host',
        mandatory: false,
        defaultsTo: 'localhost',
        help: 'Used on daemon side for npt sessions only. The host on the'
            ' daemon\'s local network to connect to; defaults to localhost.')
    ..addFlag('rv-auth',
        defaultsTo: false,
        help: '(Legacy) Whether this rv process will authenticate to rvd using'
            ' legacy "payload" (signed response to implicit challenge) auth.')
    ..addOption(
      'relay-auth-mode',
      abbr: 'a',
      mandatory: false,
      help: 'The relay auth mode, if required.',
      allowed: RelayAuthMode.values.map((c) => c.name).toList(),
    )
    ..addFlag('rv-e2ee',
        defaultsTo: false,
        help: 'Whether this rv process will encrypt/decrypt'
            ' all rvd socket traffic')
    ..addFlag('multi',
        defaultsTo: false,
        negatable: false,
        help: 'Set this flag when we want multiple connections via the rvd');

  await runZonedGuarded(() async {
    final SocketConnector sc;
    try {
      final ArgResults parsed;
      try {
        parsed = parser.parse(args);
      } on FormatException catch (e) {
        throw ArgumentError(e.message);
      }

      final String streamingHost = parsed['host'];
      final int streamingPort = int.parse(parsed['port']);
      final int localPort = int.parse(parsed['local-port']);
      final bool bindLocalPort = parsed['bind-local-port'];
      final String localHost = parsed['local-host'];
      final bool rvE2ee = parsed['rv-e2ee'];
      final bool multi = parsed['multi'];
      final Duration timeout = Duration(seconds: int.parse(parsed['timeout']));
      RelayAuthMode? relayAuthMode = parsed['relay-auth-mode'] == null
          ? null
          : RelayAuthMode.values.byName(parsed['relay-auth-mode']);
      final Duration heartbeat =
          Duration(seconds: int.parse(parsed['heartbeat']));

      String? aesC2D = rvE2ee ? Platform.environment['RV_AES_C2D'] : null;
      String? ivC2D = rvE2ee ? Platform.environment['RV_IV_C2D'] : null;

      String? aesD2C = rvE2ee ? Platform.environment['RV_AES_D2C'] : null;
      String? ivD2C = rvE2ee ? Platform.environment['RV_IV_D2C'] : null;

      if (parsed['rv-auth']) {
        if (relayAuthMode != null) {
          throw ArgumentError('Only one of "--rv-auth" (legacy)'
              ' and "--relay-auth-mode <version>" may be supplied');
        } else {
          relayAuthMode = RelayAuthMode.payload;
        }
      }

      RelayAuthenticator? relayAuthenticator;
      if (relayAuthMode != null) {
        switch (relayAuthMode) {
          case RelayAuthMode.payload:
            String? legacyAuthString =
                parsed['rv-auth'] ? Platform.environment['RV_AUTH'] : null;
            if ((legacyAuthString ?? '').isEmpty) {
              throw ArgumentError(
                  '--relay-auth-mode is v0, but RV_AUTH is not in environment');
            }
            relayAuthenticator = RelayAuthenticatorLegacy(legacyAuthString!);
            break;
          case RelayAuthMode.escr:
            String sessionId =
                Platform.environment['REMOTE_AUTH_ESCR_SESSION_ID'] ?? '';
            if (sessionId.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_SESSION_ID in env');
            }
            String relayAuthAesKey =
                Platform.environment['REMOTE_AUTH_ESCR_AES_KEY'] ?? '';
            if (relayAuthAesKey.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_AES_KEY in env');
            }
            String publicSigningKeyUri =
                Platform.environment['REMOTE_AUTH_ESCR_PUB_KEY_URI'] ?? '';
            if (publicSigningKeyUri.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_PUB_KEY_URI in env');
            }
            String publicSigningKey =
                Platform.environment['REMOTE_AUTH_ESCR_SIGNING_PUBKEY'] ?? '';
            if (publicSigningKey.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_SIGNING_PUBKEY in env');
            }
            String privateSigningKey =
                Platform.environment['REMOTE_AUTH_ESCR_SIGNING_PRIVKEY'] ?? '';
            if (privateSigningKey.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_SIGNING_PRIVKEY in env');
            }
            String isSideA =
                (Platform.environment['REMOTE_AUTH_ESCR_IS_SIDE_A'] ?? '')
                    .trim()
                    .toLowerCase();
            if (isSideA.isEmpty) {
              throw ArgumentError('No REMOTE_AUTH_ESCR_IS_SIDE_A in env');
            }
            if (isSideA != 'true' && isSideA != 'false') {
              throw ArgumentError('Env var REMOTE_AUTH_ESCR_IS_SIDE_A'
                  ' must be "true" or "false"');
            }
            relayAuthenticator = RelayAuthenticatorESCR(
              sessionId: sessionId,
              relayAuthAesKey: relayAuthAesKey,
              publicSigningKeyUri: publicSigningKeyUri,
              publicSigningKey: publicSigningKey,
              privateSigningKey: privateSigningKey,
              isSideA: isSideA == 'true',
            );
            break;
        }
      }
      if (rvE2ee && (aesC2D ?? '').isEmpty) {
        throw ArgumentError(
            '--rv-e2ee required, but RV_AES is not in environment');
      }
      if (rvE2ee && (ivC2D ?? '').isEmpty) {
        throw ArgumentError(
            '--rv-e2ee required, but RV_IV is not in environment');
      }

      sc = await Srv.dart(
        streamingHost,
        streamingPort,
        localPort: localPort,
        localHost: localHost,
        bindLocalPort: bindLocalPort,
        relayAuthenticator: relayAuthenticator,
        aesC2D: aesC2D,
        ivC2D: ivC2D,
        aesD2C: aesD2C,
        ivD2C: ivD2C,
        multi: multi,
        detached: true,
        // by definition - this is the srv binary
        timeout: timeout,
        controlChannelHeartbeat: heartbeat,
      ).run();
    } on ArgumentError catch (e) {
      printVersion();
      stderr.writeln(parser.usage);
      stderr.writeln('\n$e');

      // We will leave the log file in /tmp since we are exiting abnormally
      exit(1);
    }

    /// No more writing to stderr, as the parent process will have exited,
    /// and stderr no longer exists
    fileLoggingHandler.logToStderr = false;

    /// Wait for socket connector to close
    await sc.done;

    /// We will clean up the log file in /tmp since we are exiting normally
    try {
      fileLoggingHandler.f.deleteSync();
    } catch (_) {}

    exit(0);
  }, (error, StackTrace stackTrace) async {
    logger.shout('Unhandled exception $error; stackTrace follows\n$stackTrace');
    // Do not remove this output; it is specifically looked for in
    // [SrvImplExec.run].
    logger.shout('${Srv.completedWithExceptionString} : $error');

    // We will leave the log file in /tmp since we are exiting abnormally
    exit(200);
  });
}

class TmpFileLoggingHandler implements LoggingHandler {
  late final File f;

  bool logToStderr = true;

  TmpFileLoggingHandler() {
    if (Platform.isWindows) {
      f = File(path.normalize('${Platform.environment['TEMP']}'
          '/srv.$pid.log'));
    } else {
      f = File('/tmp/srv.$pid.log');
    }
    f.createSync(recursive: true);
  }

  @override
  void call(LogRecord record) {
    f.writeAsStringSync(
        '${record.level.name}'
        '|${record.time}'
        '|${record.loggerName}'
        '|${record.message} \n',
        mode: FileMode.writeOnlyAppend);
    if (logToStderr) {
      try {
        AtSignLogger.stdErrLoggingHandler.call(record);
      } catch (e) {
        f.writeAsStringSync('********** Failed to log to stderr: $e',
            mode: FileMode.writeOnlyAppend);
      }
    }
  }
}
