import 'package:args/args.dart';
import 'package:noports_core/sshrv.dart';

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
        mandatory: false, help: 'Auth string to provide to rvd');

  final parsed = parser.parse(args);

  final String host = parsed['host'];
  final int streamingPort = int.parse(parsed['port']);
  final int localPort = int.parse(parsed['local-port']);
  final String? rvdAuthString = parsed['rvd-auth'];
  final bool bindLocalPort = parsed['bind-local-port'];

  await Sshrv.dart(host, streamingPort,
          localPort: localPort,
          bindLocalPort: bindLocalPort,
          rvdAuthString: rvdAuthString)
      .run();
}
