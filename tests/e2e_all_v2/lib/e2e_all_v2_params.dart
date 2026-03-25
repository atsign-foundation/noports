import 'package:args/args.dart';

// Usage
// E2EAllV2Params params = E2EAllV2Params.fromArgs(args);
// print(params.clientAtsign);
class E2EAllV2Params {
  // Parameter cases
  // Case 1: mandatory (no defaults)
  // Case 2a: non-mandatory, compile-time default
  // Case 2b: non-mandatory, run-time dsdfjlasdkfe
  // Case 3: Non-mandatorry, with no default

  static ArgParser _argParser = _createArgParser();

  // Case 1 - mandatory parameters
  final String clientAtsign;
  final String daemonAtsign;
  final String relayAtsign;
  final String relayLatestAtsign;
  final String policyAtsign;
  final String policyLatestAtsign;
  final String eventsAtsign;

  // Case 2a - compile time defaults
  final String rootDomain;
  final bool verbose;

  E2EAllV2Params._({
    required this.clientAtsign,
    required this.daemonAtsign,
    required this.relayAtsign,
    required this.relayLatestAtsign,
    required this.policyAtsign,
    required this.policyLatestAtsign,
    required this.eventsAtsign,
    required this.rootDomain,
    required this.verbose,
  });

  factory E2EAllV2Params.fromArgs(List<String> args) {
    ArgResults argResults = _argParser.parse(args);
    E2EAllV2Params e2eAllV2Params = E2EAllV2Params._(
      clientAtsign: argResults['client-atsign'],
      daemonAtsign: argResults['daemon-atsign'],
      relayAtsign: argResults['relay-atsign'],
      relayLatestAtsign: argResults['relay-latest-atsign'],
      policyAtsign: argResults['policy-atsign'],
      policyLatestAtsign: argResults['policy-latest-atsign'],
      eventsAtsign: argResults['events-atsign'],
      rootDomain: argResults['root-domain'],
      verbose: argResults['verbose'],
    );
    return e2eAllV2Params;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();
    argParser.addOption('client-atsign',
      mandatory: true, 
      help: 'client Atsign that will be used in tests', 
    );
    argParser.addOption('daemon-atsign',
      mandatory: true,
      help: 'daemon Atsign that will be used in tests',
    );
    argParser.addOption('relay-atsign',
      mandatory: true,
      help: 'relay Atsign that will be used in tests',
    );
    argParser.addOption('relay-latest-atsign',
      mandatory: true,
      help: 'the relay Atsign to test aganist the most recent code changes',
    );
    argParser.addOption('policy-atsign',
      mandatory: true,
      help: 'policy Atsign will be used in tests',
    );
    argParser.addOption('policy-latest-atsign',
      mandatory: true,
      help: 'the policy Atsign that will be used against the most recent code changes',
    );
    argParser.addOption('events-atsign',
      mandatory: true,
      help: 'the events Atsign that will be used against the most recent code changes',
    );
    return argParser;
  }
}
