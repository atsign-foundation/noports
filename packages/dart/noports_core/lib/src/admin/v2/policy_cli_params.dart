import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

class PolicyCLIParamsDefaults {
  static const bool verbose = false;
  static const String rootServer = 'root.atsign.org:64';
  static const String namespace = 'sshnp';
  static const String policyVersion = 'v1';
}

class PolicyCLIParams {
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

  // Non-mandatory with resolvable defaults (this is case 2):
  // Case 2a:
  late bool _verbose; // will always be non-null; it has a resolvable default
  late String _rootServer; // will always be non-null; it has a resolvable default
  late String _namespace;
  late String _policyVersion;

  // Case 2b:
  late String _atKeysFilePath; // resolves to ~/.atsign/keys/<atsign>-key.atKeys
  late String _policyAtSign; // non-null, resolves to _atSign if not specified by ArgParser

  // Case 3: Non-mandatory with no defaults (null, if not specified).
  String? _storagePath;

  static final ArgParser _argParser = _createArgParser();

  // private constructor, please use `.fromArgs` factory to instantiate
  PolicyCLIParams._({
    required String atSign,
  }) : _atSign = atSign;

  String get atSign => _atSign;
  bool get verbose => _verbose;
  String get rootServer => _rootServer;
  String get atKeysFilePath => _atKeysFilePath;
  String get policyAtSign => _policyAtSign;
  String get namespace => _namespace;
  String get policyVersion => _policyVersion;
  String? get storagePath => _storagePath;

  factory PolicyCLIParams.fromArgs(List<String> args) {
    ArgResults argResults = _argParser.parse(args);
    final String atSign = argResults['atsign'];
    final String? homeDirectory = getHomeDirectory(throwIfNull: false);
    if(homeDirectory == null && argResults['key-file'] == null) {
      throw Exception('Home Directory not found and key-file was not '
        'specified. I don\'t know where to find the .atKeys file.');
    }
    PolicyCLIParams p = PolicyCLIParams._(
      atSign: atSign, // mandatory option
    );

    // Case 2a: gets value or default from ArgParser
    p._verbose = argResults['verbose'];
    p._rootServer = argResults['root-server'];
    p._namespace = argResults['namespace'];
    p._policyVersion = argResults['policy-version'];

    // Case 2b: resolve to our own default (default cannot be obtained from ArgParser)
    p._atKeysFilePath = argResults['key-file'] ?? 
      getDefaultAtKeysFilePath(homeDirectory!, atSign);
    p._policyAtSign = argResults['policy-atsign'] ??
      p._atSign;

    // Case 3: Non-mandatory nullable variables
    p._storagePath = argResults['storage-path'];
    return p;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();

    // Case 1: Manatory options
    argParser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'policy atSign',
    );

    // Case 2a: Non-mandatory, but has defaultsTo:
    // Be sure to use PolicyCLIParamsDefaults
    argParser.addOption(
      'root-server',
      mandatory: false,
      defaultsTo: PolicyCLIParamsDefaults.rootServer,
      help: 'host:port of the atDirectory',
      aliases: const ['root-domain'],
    );

    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: PolicyCLIParamsDefaults.verbose,
      help: 'Extra logging',
    );

    argParser.addOption(
      'namespace',
      mandatory: false,
      defaultsTo: PolicyCLIParamsDefaults.namespace,
      help: 'Namespace of the application, defaults to ${PolicyCLIParamsDefaults.namespace}'
    );

    argParser.addOption(
      'policy-version',
      mandatory: false,
      defaultsTo: PolicyCLIParamsDefaults.policyVersion,
      help: 'Policy version that the server is using, defaults to v1, '
        'other possible value is \'v2\'',
    );

    // Case 2b: Non-mandatory, but does not have defaultsTo:
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
      help: 'Policy atSign, defaults to the specified -a atSign'
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

