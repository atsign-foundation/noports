import 'package:args/args.dart';

const String defaultRelayClientVersions = 'd:current';
const String defaultRelayDaemonVersions = 'd:current';
const String defaultSelfRelayVersions = 'd:v5.10.0,d:current';

class RelayTestsParams {
  static final ArgParser argParser = _createArgParser();

  late String clientAtsign;
  late String daemonAtsign;
  late String prodRelayAtsign;
  late String selfRelayAtsigns;
  late bool help;
  late String rootDomain;
  late bool verbose;
  late String baseDirectory;
  late String clientVersions;
  late String daemonVersions;
  late String selfRelayVersions;
  late int batchSize;
  late int maxRetries;
  late int testTimeoutSeconds;
  late String? testRunId;

  RelayTestsParams._();

  factory RelayTestsParams.parse(List<String> args) {
    final ArgResults argResults = argParser.parse(args);
    final RelayTestsParams params = RelayTestsParams._();
    params.help = argResults['help'];
    if (params.help) {
      return params;
    }
    params.clientAtsign = argResults['client-atsign'];
    params.daemonAtsign = argResults['daemon-atsign'];
    params.prodRelayAtsign = argResults['prod-relay'];
    params.selfRelayAtsigns = argResults['self-relay-atsigns'];
    params.rootDomain = argResults['root-domain'];
    params.verbose = argResults['verbose'];
    params.baseDirectory = argResults['base-directory'];
    params.clientVersions = argResults['client-versions'];
    params.daemonVersions = argResults['daemon-versions'];
    params.selfRelayVersions = argResults['self-relay-versions'];
    params.batchSize = int.parse(argResults['batch-size']);
    params.maxRetries = int.parse(argResults['max-retries']);
    params.testTimeoutSeconds = int.parse(argResults['test-timeout-seconds']);
    params.testRunId = argResults['test-run-id'];
    if (params.selfRelayAtsigns
        .split(',')
        .map((atsign) => atsign.trim())
        .where((atsign) => atsign.isNotEmpty)
        .isEmpty) {
      throw ArgumentError('self-relay-atsigns must not be empty');
    }
    return params;
  }

  static ArgParser _createArgParser() {
    final ArgParser parser = ArgParser();
    parser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    );
    parser.addOption('client-atsign', abbr: 'c', help: 'Atsign for the client');
    parser.addOption('daemon-atsign', abbr: 'd', help: 'Atsign for the daemon');
    parser.addOption(
      'prod-relay',
      aliases: ['prod-relay-atsign'],
      help: 'Atsign for the prod relay',
    );
    parser.addOption(
      'self-relay-atsigns',
      aliases: ['self-relay-atsign'],
      help: 'Comma-separated atSigns for self-run relays',
    );
    parser.addOption(
      'root-domain',
      abbr: 'r',
      defaultsTo: 'root.atsign.org:64',
      help: 'Root domain to use',
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      defaultsTo: false,
      help: 'Enable verbose logging',
    );
    parser.addOption(
      'base-directory',
      abbr: 'b',
      defaultsTo: './npe2e_relay',
      help: 'Base directory for test results',
    );
    parser.addOption(
      'client-versions',
      defaultsTo: defaultRelayClientVersions,
      help: 'Comma-separated list of client versions to test',
    );
    parser.addOption(
      'daemon-versions',
      defaultsTo: defaultRelayDaemonVersions,
      help: 'Comma-separated list of daemon versions to test',
    );
    parser.addOption(
      'self-relay-versions',
      defaultsTo: defaultSelfRelayVersions,
      help: 'Comma-separated list of self-run relay versions to test',
    );
    parser.addOption(
      'batch-size',
      defaultsTo: '1',
      help: 'Number of tests to run in parallel',
    );
    parser.addOption(
      'max-retries',
      defaultsTo: '3',
      help: 'Maximum number of times to retry a failing test',
    );
    parser.addOption(
      'test-timeout-seconds',
      defaultsTo: '300',
      help: 'Timeout in seconds for each individual test before it is failed and retried',
    );
    parser.addOption(
      'test-run-id',
      help: 'Unique identifier for this test run (optional)',
    );
    return parser;
  }

  static void printUsage() {
    print('Usage: dart relay_tests.dart [options]');
    print(argParser.usage);
  }
}
