import 'package:args/args.dart';

const String defaultClientVersions = 'd:current';
const String defaultDaemonVersions = 'd:current';
const String defaultNppAtServerVersions = 'd:v5.13.0';
const String defaultNppVersions = 'd:current';

class PolicyTestsParams {
  static final ArgParser argParser = _createArgParser();

  // Case 1: mandatory params
  late String clientAtsign;
  late String daemonAtsign;
  late String relayAtsign;
  late String nppAtServerAtsign;
  late String nppAtsign;

  // Case 2a: compile-time defaults
  late bool help;

  late String rootDomain;
  late bool verbose;
  late String baseDirectory;
  late String clientVersions;
  late String daemonVersions;
  late String nppAtServerVersions;
  late String nppVersions;
  late int batchSize;
  late int maxRetries;
  late int testTimeoutSeconds;

  // Case 2b: run-time defaults
  late String? testRunId;

  // Private constructor
  PolicyTestsParams._();

  factory PolicyTestsParams.parse(List<String> args) {
    final ArgResults argResults = argParser.parse(args);
    final PolicyTestsParams params = PolicyTestsParams._();
    params.help = argResults['help'];
    if (params.help) {
      return params;
    }
    params.clientAtsign = argResults['client-atsign'];
    params.daemonAtsign = argResults['daemon-atsign'];
    params.relayAtsign = argResults['relay-atsign'];
    params.nppAtServerAtsign = argResults['npp-atserver-atsign'];
    params.nppAtsign = argResults['npp-atsign'];
    params.rootDomain = argResults['root-domain'];
    params.verbose = argResults['verbose'];
    params.baseDirectory = argResults['base-directory'];
    params.clientVersions = argResults['client-versions'];
    params.daemonVersions = argResults['daemon-versions'];
    params.nppAtServerVersions = argResults['npp-atserver-versions'];
    params.nppVersions = argResults['npp-versions'];
    params.batchSize = int.parse(argResults['batch-size']);
    params.maxRetries = int.parse(argResults['max-retries']);
    params.testTimeoutSeconds = int.parse(argResults['test-timeout-seconds']);
    params.testRunId = argResults['test-run-id'];
    if (params.nppAtsign == params.nppAtServerAtsign) {
      throw ArgumentError(
        'npp-atsign and npp-atserver-atsign must be distinct',
      );
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
    parser.addOption('relay-atsign', help: 'Atsign for the relay');
    parser.addOption(
      'npp-atserver-atsign',
      help: 'Atsign for the NPP at server',
    );
    parser.addOption('npp-atsign', abbr: 'n', help: 'Atsign for the NPP');
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
      defaultsTo: './npe2e_policy',
      help: 'Base directory for test results',
    );
    parser.addOption(
      'client-versions',
      defaultsTo: defaultClientVersions,
      help: 'Comma-separated list of client versions to test',
    );
    parser.addOption(
      'daemon-versions',
      defaultsTo: defaultDaemonVersions,
      help: 'Comma-separated list of daemon versions to test',
    );
    parser.addOption(
      'npp-atserver-versions',
      defaultsTo: defaultNppAtServerVersions,
      help: 'Comma-separated list of NPP atServer versions to test',
    );
    parser.addOption(
      'npp-versions',
      defaultsTo: defaultNppVersions,
      help: 'Comma-separated list of NPP versions to test',
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
      help:
          'Timeout in seconds for each individual test before it is failed and retried',
    );
    parser.addOption(
      'test-run-id',
      help: 'Unique identifier for this test run (optional)',
    );
    return parser;
  }

  static void printUsage() {
    print('Usage: dart policy_tests.dart [options]');
    print(argParser.usage);
  }
}
