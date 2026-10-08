import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

class NPPCLIParamsDefaults {
  static const bool verbose = false;
  static const String rootServer = 'root.atsign.org:64';
  static const String baseNamespace = 'sshnp';
  static const String domainNamespace = 'npp';
}

class NPPCLIParams {
  // The goal of PolicyCLIParams is to have all parameters non-null after
  // parsing command-line arguments.
  // There are three categories of parameters:
  // 1. Mandatory options (no defaults, must be specified by ArgParser), should be a final variable
  // 2. Non-mandatory options with resolvable defaults
  //    a. has a compile-time default (e.g. _rootServer); the default comes from ArgParser's defaultsTo, should be a final non-null variable
  //    b. has a run-time default (e.g. _atKeysFilePath)
  // 3. Non-mandatory options with no defaults (null if not specified), should be a non-final nullable variable

  // Mandatory by ArgParser (this is case 1)
  final String _atSign; // policy atSign, will always be specified (mandatory option)

  // Non-mandatory with resolvable non-null defaults (this is case 2):
  // Case 2a: compile-time default
  late bool _verbose; // will always be non-null; it has a resolvable default
  late String _rootServer; // will always be non-null; it has a resolvable default
  late String _baseNamespace; // e.g. 'sshnp'
  late String _domainNamespace; // e.g. 'npp'

  // Case 2b: run-time default
  late String _atKeysFilePath; // resolves to ~/.atsign/keys/<atsign>-key.atKeys
  late String _policyAtSign; // non-null, resolves to _atSign if not specified by ArgParser

  // Case 3: Non-mandatory with no defaults (null, if not specified).
  String? _storagePath;

  static final ArgParser _argParser = _createArgParser();

  // Public getter for argParser to allow early help/version checks
  static ArgParser get argParser => _argParser;

  // private constructor, please use `.fromArgs` factory to instantiate
  NPPCLIParams._({
    required String atSign,
  }) : _atSign = atSign;

  String get atSign => _atSign;
  bool get verbose => _verbose;
  String get rootServer => _rootServer;
  String get atKeysFilePath => _atKeysFilePath;
  String get policyAtSign => _policyAtSign;
  String get baseNamespace => _baseNamespace;

  String? get storagePath => _storagePath;
  String? get domainNamespace => _domainNamespace;

  factory NPPCLIParams.fromArgs(List<String> args) {
    ArgResults argResults = _argParser.parse(args);
    final String atSign = argResults['atsign'];
    final String? homeDirectory = getHomeDirectory(throwIfNull: false);
    if(homeDirectory == null && argResults['key-file'] == null) {
      throw Exception('Home Directory not found and key-file was not '
        'specified. I don\'t know where to find the .atKeys file.');
    }
    NPPCLIParams p = NPPCLIParams._(
      atSign: atSign, // mandatory option
    );

    // Case 2a: gets value or default from ArgParser
    p._verbose = argResults['verbose'];
    p._rootServer = argResults['root-domain'];
    p._baseNamespace = argResults['base-namespace'];
    p._domainNamespace = argResults['domain-namespace'];

    // Case 2b: resolve to our own default 
    //(default cannot be obtained from ArgParser)
    p._atKeysFilePath = argResults['key-file'] ?? 
      getDefaultAtKeysFilePath(homeDirectory!, atSign);
    p._policyAtSign = argResults['policy-atsign'] ?? p._atSign;

    // Case 3: Non-mandatory nullable variables
    p._storagePath = argResults['storage-path'];

    return p;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();

    argParser.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show usage instructions',
    );

    argParser.addFlag(
      'version',
      negatable: false,
      help: 'Show version information',
    );

    // Case 1: Manatory options
    argParser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign to authenticate as (your atSign)',
    );

    // Case 2a: Non-mandatory, but has defaultsTo:
    // Be sure to use PolicyCLIParamsDefaults
    argParser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: NPPCLIParamsDefaults.rootServer,
      help: 'host:port of the atDirectory',
      aliases: const ['root-server'],
    );

    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: NPPCLIParamsDefaults.verbose,
      help: 'Extra logging',
    );

    argParser.addOption(
      'base-namespace',
      mandatory: false,
      defaultsTo: NPPCLIParamsDefaults.baseNamespace,
      help: 'Namespace of the application, defaults to '
        '${NPPCLIParamsDefaults.baseNamespace}.'
    );

    argParser.addOption(
      'domain-namespace',
      mandatory: false,
      defaultsTo: NPPCLIParamsDefaults.domainNamespace,
      help: 'Domain namespace of the application, defaults to "npp".'
    );

    // Case 2b: Non-mandatory, does not have defaultsTo:
    // has a compile-time default
    argParser.addOption(
      'key-file',
      mandatory: false,
      aliases: const ['keys', 'keyFile', 'keysFile'],
      help: 'atSign\'s atKeys file if not in '
        '~/.atsign/keys/<@atSign>_key.atKeys'
    );

    argParser.addOption(
      'policy-atsign',
      mandatory: false,
      help: 'atSign of the policy service to connect to. '
        'Defaults to the -a atSign (connects to your own policy service)'
    );

    // Case 3: Non-mandatory 
    argParser.addOption(
      'storage-path',
      abbr: 's',
      mandatory: false,
      help: 'Specified storage directory',
    );

    return argParser;
  }

}

