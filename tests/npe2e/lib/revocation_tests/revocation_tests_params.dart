import 'package:args/args.dart';

/// The command-line parameters of the revocation tests.
class RevocationTestsParams {
  static final ArgParser argParser = _createArgParser();

  late bool help;
  late String clientAtsign;
  late String daemonAtsign;
  late String relayAtsign;
  late String rootDomain;
  late String relayHost;
  late String baseDirectory;
  late String daemonVersions;
  late String unsignedClientVersion;
  late int withdrawnWithinSeconds;
  late String? testRunId;

  RevocationTestsParams._();

  factory RevocationTestsParams.parse(List<String> args) {
    final ArgResults r = argParser.parse(args);
    final RevocationTestsParams params = RevocationTestsParams._();
    params.help = r['help'];
    if (params.help) {
      return params;
    }
    params.clientAtsign = r['client-atsign'];
    params.daemonAtsign = r['daemon-atsign'];
    params.relayAtsign = r['relay-atsign'];
    params.rootDomain = r['root-domain'];
    params.relayHost = r['relay-host'] ?? params.rootDomain.split(':').first;
    params.baseDirectory = r['base-directory'];
    params.daemonVersions = r['daemon-versions'];
    params.unsignedClientVersion = r['unsigned-client-version'];
    params.withdrawnWithinSeconds = int.parse(r['withdrawn-within-seconds']);
    params.testRunId = r['test-run-id'];
    return params;
  }

  static void printUsage() {
    print('Usage: dart run tests/npe2e/bin/revocation_tests.dart [options]');
    print('');
    print(argParser.usage);
  }

  static ArgParser _createArgParser() {
    return ArgParser()
      ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help')
      ..addOption(
        'client-atsign',
        mandatory: true,
        help: 'Client atSign, whose keys in ~/.atsign/keys can enroll and'
            ' revoke devices',
      )
      ..addOption('daemon-atsign', mandatory: true, help: 'Daemon atSign')
      ..addOption(
        'relay-atsign',
        mandatory: true,
        help: 'atSign of the srvd these tests start themselves',
      )
      ..addOption(
        'root-domain',
        mandatory: true,
        help: 'atDirectory host:port, e.g. vip.ve.atsign.zone:2500 for an EE'
            ' or vip.ve.atsign.zone for the VE',
      )
      ..addOption(
        'relay-host',
        help: 'Name srvd advertises, which the host and the daemon containers'
            ' must both resolve (defaults to the root domain\'s host)',
      )
      ..addOption(
        'base-directory',
        defaultsTo: 'npe2e_revocation_tests',
        help: 'Where run artefacts (binaries, keys, logs) are written',
      )
      ..addOption(
        'daemon-versions',
        defaultsTo: 'd:current,c:current',
        help: 'Comma-separated language:version of the daemons to test',
      )
      ..addOption(
        'unsigned-client-version',
        defaultsTo: 'd:v5.17.0',
        help: 'A released client that does not sign its requests with its'
            ' enrollment key',
      )
      ..addOption(
        'withdrawn-within-seconds',
        defaultsTo: '45',
        help: 'How long after revocation a session may take to end',
      )
      ..addOption(
        'test-run-id',
        help: 'Names this run\'s directory, devices and containers (defaults'
            ' to the short git hash)',
      );
  }
}
