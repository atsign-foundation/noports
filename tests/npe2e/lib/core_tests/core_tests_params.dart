import 'package:args/args.dart';

// Default version strings
const String defaultClientVersions = 'd:v5.9.4,d:v5.11.2,d:v5.13.0,d:current';
const String defaultDaemonVersions =
    'd:v5.9.4,d:v5.11.2,d:v5.13.0,d:current,c:current';

// Usage
// E2EAllV2Params params = E2EAllV2Params.fromArgs(args);
// print(params.clientAtsign);
class CoreTestsParams {
  // Parameter cases
  // Case 1: mandatory (no defaults)
  // Case 2a: non-mandatory, compile-time default
  // Case 2b: non-mandatory, run-time
  // Case 3: Non-mandatorry, with no default

  static final ArgParser argParser = _createArgParser();

  // Case 1 - mandatory parameters
  late String clientAtsign;
  late String daemonAtsign;
  late String relayAtsign;
  late String unauthorizedAtsign;

  // Case 2a - compile time defaults
  late bool help;

  late String rootDomain;
  late bool verbose;
  late String baseDirectory;
  late String clientVersions;
  late String daemonVersions;
  late int batchSize;
  late int maxRetries;
  late int testTimeoutSeconds;

  // Case 2b - run-time defaults
  late String? testRunId;

  // Private constructor
  CoreTestsParams._();

  factory CoreTestsParams.parse(List<String> args) {
    final ArgResults argResults = argParser.parse(args);
    final CoreTestsParams e2eAllV2Params = CoreTestsParams._();
    e2eAllV2Params.help = argResults['help'];
    e2eAllV2Params.clientAtsign = argResults['client-atsign'];
    e2eAllV2Params.daemonAtsign = argResults['daemon-atsign'];
    e2eAllV2Params.relayAtsign = argResults['relay-atsign'];
    e2eAllV2Params.unauthorizedAtsign = argResults['unauthorized-atsign'];
    e2eAllV2Params.rootDomain = argResults['root-domain'];
    e2eAllV2Params.verbose = argResults['verbose'];
    e2eAllV2Params.baseDirectory = argResults['base-directory'];
    e2eAllV2Params.clientVersions = argResults['client-versions'];
    e2eAllV2Params.daemonVersions = argResults['daemon-versions'];
    e2eAllV2Params.batchSize = int.parse(argResults['batch-size']);
    e2eAllV2Params.maxRetries = int.parse(argResults['max-retries']);
    e2eAllV2Params.testTimeoutSeconds = int.parse(
      argResults['test-timeout-seconds'],
    );
    e2eAllV2Params.testRunId = argResults['test-run-id'];
    return e2eAllV2Params;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();
    argParser.addFlag(
      'help',
      defaultsTo: false,
      help: 'Shows usage instructions',
    );
    argParser.addOption(
      'client-atsign',
      mandatory: true,
      help: 'Client Atsign that will be used in tests',
    );
    argParser.addOption(
      'daemon-atsign',
      mandatory: true,
      help: 'Daemon Atsign that will be used in tests',
    );
    argParser.addOption(
      'relay-atsign',
      mandatory: true,
      help: 'Relay Atsign that will be used in tests',
    );
    argParser.addOption(
      'unauthorized-atsign',
      mandatory: true,
      help:
          'An atSign whose atKeys are available but is not in any daemon manager list, used for unauthorized rejection tests',
    );
    argParser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org:64', // TODO make into a constant somewhere
      help: 'Host and port of atDirectory server',
    );
    argParser.addFlag('verbose', defaultsTo: false, help: 'More logging');
    argParser.addOption(
      'base-directory',
      mandatory: false,
      defaultsTo: 'npe2e_core_tests',
      help: 'Directory where all test related artifacts are stored',
    );
    argParser.addOption(
      'client-versions',
      mandatory: false,
      defaultsTo: defaultClientVersions,
      help:
          'Comma-separated list of client versions in format language:version (e.g., d:v5.9.4,c:current)',
    );
    argParser.addOption(
      'daemon-versions',
      mandatory: false,
      defaultsTo: defaultDaemonVersions,
      help:
          'Comma-separated list of daemon versions in format language:version (e.g., d:v5.9.4,c:current)',
    );
    argParser.addOption(
      'batch-size',
      mandatory: false,
      defaultsTo: '4',
      help: 'Number of tests to run concurrently in each batch',
    );
    argParser.addOption(
      'max-retries',
      mandatory: false,
      defaultsTo: '3',
      help: 'Maximum number of times to retry a failing test',
    );
    argParser.addOption(
      'test-timeout-seconds',
      mandatory: false,
      defaultsTo: '300',
      help:
          'Timeout in seconds for each individual test before it is failed and retried',
    );
    argParser.addOption(
      'test-run-id',
      mandatory: false,
      help:
          'Test run identifier (defaults to shortened git commit hash if not provided)',
    );
    return argParser;
  }

  static void printUsage() {
    print('npe2e usage:');
    print(argParser.usage);
  }
}
