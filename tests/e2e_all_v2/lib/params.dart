

import 'package:args/args.dart';

class E2EAllV2Params {

  // Parameter cases
  // Case 1: mandatory (no defaults)
  // Case 2a: non-mandatory, compile-time default
  // Case 2b: non-mandatory, run-time default
  // Case 3: Non-mandatorry, with no default

  final ArgParser _argParser;

  // Case 1
  final String _clientAtSign;
  final String _daemonAtSign;
  final String _relayAtSign;
  final String _relayLatestAtSign;
  final String _policyAtSign;
  final String _eventsAtSign;

  // Case 2a
  late String _rootDomain;
  late bool _verbose;

  // Case 2b

  E2EAllV2Params._(
  );

  factory E2EAllV2Params.fromArgParser(List<String> args) {
    ArgResults argResults = _argParser.parse(args);
    
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();

    return argParser;
  }
}
