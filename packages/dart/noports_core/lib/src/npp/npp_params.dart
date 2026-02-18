import 'dart:io';

import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

/// Params cases

/// Case 1: Mandatory (mandatory: true in ArgParser)
/// Case 2: Non-mandatory
///   2a: compile-time default (specified by defaultsTo:)
///   2b: run-time default
/// Case 3: Optional (no default, nullable)

class NPPParams {
  // -----------
  // Case 1: Mandatory options
  // -----------
  final String atSign; 

  // -----------
  // Case 2a: Non-mandatory options with compile-time defaults
  // -----------
  late bool help;
  late bool verbose;
  late String rootDomain;
  late String baseNamespace;
  late String domainNamespace;
  late String persistenceMethod; // {'atserver', 'file', 'none'}

  // -----------
  // Case 2b: Non-mandatory options with run-time defaults
  // -----------
  late String atKeysFilePath;
  late String managerAllowList;
  late String storagePath;

  // -----------
  // Case 3: Optional options
  // -----------
  String? eventLoggingAtSign;
  String? policyDirectory;

  static final ArgParser argParser = _createArgParser();

  NPPParams._({
    required this.atSign,
  });

  factory NPPParams.fromArgs(List<String> args) {
    ArgResults argResults = argParser.parse(args);

    // -------------------
    // Case 1:
    final String atSign = argResults['atsign'];
    // -------------------

    final String? homeDirectory = getHomeDirectory(throwIfNull: false);
    if(homeDirectory == null) {
      throw Exception('Could not resolve homeDirectory');
    }

    NPPParams nppParams = NPPParams._(atSign: atSign);

    // -------------------
    // Case 2a:
    nppParams.help = argResults['help'];
    nppParams.verbose = argResults['verbose'];
    nppParams.rootDomain = argResults['root-domain'];
    nppParams.baseNamespace = argResults['base-namespace'];
    nppParams.domainNamespace = argResults['domain-namespace'];
    nppParams.persistenceMethod = argResults['persistence-method'];
    // -------------------

    // -------------------
    // Case 2b:
    nppParams.atKeysFilePath = argResults['key-file'] ??
      getDefaultAtKeysFilePath(homeDirectory, atSign);
    nppParams.managerAllowList = argResults['manager-allow-list'] ??
      atSign;
    nppParams.storagePath = argResults['storage-path'] ??
      standardAtClientStoragePath(
        baseDir: homeDirectory,
        atSign: atSign,
        progName: nppParams.baseNamespace,
        uniqueID: 'single', // What does this mean?
      );
    // -------------------


    // -------------------
    // Case 3:
    nppParams.eventLoggingAtSign = argResults['event-logging-atsign'];
    nppParams.policyDirectory = argResults['policy-directory'];
    // -------------------

    return nppParams;
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    final ArgParser argParser = ArgParser(usageLineLength: usageLineLength);

    // ----- Case 1: -----
    argParser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign that the policy server will run as.'
    );

    // ----- Case 2a: -----
    argParser.addFlag('help', defaultsTo: false, negatable: false, help: 'Show usage instructions');
    argParser.addFlag('version', defaultsTo: false, negatable: false, help: 'Show version');

    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      negatable: true,
      help: 'Enable verbose logging'
    );

    argParser.addOption(
      'root-domain',
      aliases: const ['root-server', 'rootDomain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org:64',
      help: 'atDirectory root domain, defaults to root.atsign.org:64',
    );

    argParser.addOption(
      'base-namespace',
      aliases: const ['namespace'],
      mandatory: false,
      defaultsTo: 'sshnp',
      help: 'Application namespace', // TODO more helpful help message
    );

    argParser.addOption(
      'domain-namespace',
      mandatory: false,
      defaultsTo: 'npp',
      help: 'Domain namespace', // TODO more helpful help message
    );

    argParser.addOption(
      'persistence-method',
      mandatory: false,
      defaultsTo: 'atserver',
      help: 'Define the persistence of the policy data.'
        ' Method to use for persistence of policy data. Options are:'
        ' "atserver" (default), "file" or "none". "atserver" uses the atSign'
        '\'s atServer for persistence of policy data. "file" uses local file'
        ' storage for policy data persistence. "none" means that policy data'
        ' will not be saved anywhere and will be lost when the service stops.',
    );


    // ----- Case 2b: -----
    argParser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile', 'keys'],
      help: 'The atSign\'s atKeys file if not in ~/.atsign/keys/',
    );

    argParser.addOption(
      'manager-allow-list',
      mandatory: false,
      help:
        'List of atSigns that can manage policy data and send RPCs to the'
        ' Policy Manager API.'
        ' atSigns in this list can send policy operations (puts/gets) to'
        ' the policy service API. E.g.'
        ' "@alice,@bob,@meow". Defaults to atSign specified by `-a` option'
        ' e.g. "@alice". Set it to empty string ("") to disable any atSigns'
        ' from editing policy rules.'
    );

    argParser.addOption(
      'storage-path',
      abbr: 's',
      mandatory: false,
      help:
        'Path to atsign storage directory.'
        ' Running multiple CLI atClient programs with the same storage path is'
        ' not supported. An alternate storage directory can be passed through'
        ' this argument when running multiple instances.',
    );

    // ----- Case 3: -----
    argParser.addOption(
      'event-logging-atsign',
      mandatory: false,
      help: 'atSign of a noports logging service.'
    );

    argParser.addOption(
      'policy-directory',
      mandatory: false,
      help:
        'This option only applies when using --persistence-method="file".'
        'Path to npp storage directory where policy rules are stored in '
        'file format.'
    );

    return argParser;
  }
}
