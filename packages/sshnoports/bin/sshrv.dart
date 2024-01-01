import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_core/sshrv.dart';
import 'package:socket_connector/socket_connector.dart';

Future<void> main(List<String> args) async {
  final ArgParser parser = ArgParser()
    ..addOption('host', abbr: 'h', mandatory: true, help: 'rvd host')
    ..addOption('port', abbr: 'p', mandatory: true, help: 'rvd port')
    ..addOption('local-port',
        defaultsTo: '22',
        help: 'Local port (usually the sshd port) to bridge to; defaults to 22')
    ..addFlag('bind-local-port',
        defaultsTo: false,
        negatable: false,
        help: 'Set this flag when we are bridging from a local sender')
    ..addOption('rvd-auth',
        mandatory: false, help: 'Auth string to provide to rvd')
    ..addOption('aes-key',
        mandatory: false, help: 'AES key to use for session encryption')
    ..addOption('iv',
        mandatory: false, help: 'IV to use for session encryption');

  final parsed = parser.parse(args);

  final String host = parsed['host'];
  final int streamingPort = int.parse(parsed['port']);
  final int localPort = int.parse(parsed['local-port']);
  final String? rvdAuthString = parsed['rvd-auth'];
  final bool bindLocalPort = parsed['bind-local-port'];
  final String? sessionAESKeyString = parsed['aes-key'];
  final String? sessionIVString = parsed['iv'];

  SocketConnector connector = await Sshrv.dart(
    host,
    streamingPort,
    localPort: localPort,
    bindLocalPort: bindLocalPort,
    rvdAuthString: rvdAuthString,
    sessionAESKeyString: sessionAESKeyString,
    sessionIVString: sessionIVString,
  ).run();

  /// Shut myself down once the socket connector closes
  stderr.writeln('Waiting for connector to close');
  await connector.closed();

  stderr.writeln('Closed - exiting');
  exit(0);
}
