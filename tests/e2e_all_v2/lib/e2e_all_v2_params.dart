import 'package:args/args.dart';

// Usage
// E2EAllV2Params params = E2EAllV2Params.fromArgs(args);
// print(params.clientAtsign);
class E2EAllV2Params {
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
  late String policyAtsign;
  late String eventsAtsign;

  // Case 2a - compile time defaults
  late bool help;

  late String rootDomain;
  late bool verbose;
  late String logDirectory;

  // Private constructor
  E2EAllV2Params._();

  factory E2EAllV2Params.parse(List<String> args) {
    final ArgResults argResults = argParser.parse(args);
    final E2EAllV2Params e2eAllV2Params = E2EAllV2Params._();
    e2eAllV2Params.help = argResults['help'];
    e2eAllV2Params.clientAtsign = argResults['client-atsign'];
    e2eAllV2Params.daemonAtsign = argResults['daemon-atsign'];
    e2eAllV2Params.relayAtsign = argResults['relay-atsign'];
    e2eAllV2Params.policyAtsign = argResults['policy-atsign'];
    e2eAllV2Params.eventsAtsign = argResults['events-atsign'];
    e2eAllV2Params.rootDomain = argResults['root-domain'];
    e2eAllV2Params.verbose = argResults['verbose'];
    e2eAllV2Params.logDirectory = argResults['log-directory'];
    return e2eAllV2Params;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();
    argParser.addFlag('help',
      defaultsTo: false,
      help: 'Shows usage instructions',
    );
    argParser.addOption('client-atsign',
      mandatory: true, 
      help: 'Client Atsign that will be used in tests', 
    );
    argParser.addOption('daemon-atsign',
      mandatory: true,
      help: 'Daemon Atsign that will be used in tests',
    );
    argParser.addOption('relay-atsign',
      mandatory: true,
      help: 'Relay Atsign that will be used in tests',
    );
    argParser.addOption('policy-atsign',
      mandatory: true,
      help: 'Policy Atsign will be used in tests',
    );
    argParser.addOption('events-atsign',
      mandatory: true,
      help: 'The events Atsign that will be used against the most recent code changes',
    );
    argParser.addOption('root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org:64', // TODO make into a constant somewhere
      help: 'Host and port of atDirectory server'
    );
    argParser.addFlag('verbose',
      defaultsTo: false,
      help: 'More logging',
    );
    argParser.addOption('log-directory',
      mandatory: false,
      defaultsTo: 'logs',
      help: 'Directory where all Docker operation logs will be stored',
    );
    return argParser;
  }

  static void printUsage() {
    print('e2e_all_v2 usage:');
    print(argParser.usage);
  }

}
