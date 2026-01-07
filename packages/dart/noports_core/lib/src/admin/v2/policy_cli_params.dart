import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';

class PolicyCLIParams {
  final String atSign; // policy atSign
  final bool verbose;
  final String rootServer;
  final String atKeysFilePath;

  static ArgParser argParser = _createArgParser();

  PolicyCLIParams({
    required this.atSign,
    required this.verbose,
    required this.rootServer,
    required this.atKeysFilePath,
  });

  factory PolicyCLIParams.fromArgs(List<String> args) {
    ArgResults argResults = argParser.parse(args);
    final String atSign = argResults['atsign'];
    final String? homeDirectory = getHomeDirectory(throwIfNull: false);
    if(homeDirectory == null && argResults['key-file'] == null) {
      throw Exception('Home Directory not found and key-file was not '
        'specified. I don\'t know where to find the .atKeys file.');
    }
    PolicyCLIParams p = PolicyCLIParams(
      atSign: atSign, // mandatory option
      verbose: argResults['verbose'], // false by default
      rootServer: argResults['root-server'], // root.atsign.org:64 by default
      atKeysFilePath: argResults['key-file'] ?? 
        getDefaultAtKeysFilePath(homeDirectory!, atSign),
    );
    return p;
  }

  static ArgParser _createArgParser() {
    final ArgParser argParser = ArgParser();

    argParser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'policy atSign',
    );

    argParser.addOption(
      'root-server',
      mandatory: false,
      defaultsTo: 'root.atsign.org:64',
      help: 'host:port of the atDirectory',
      aliases: const ['root-domain'],
    );

    argParser.addOption(
      'key-file',
      mandatory: false,
      aliases: const ['keys', 'keyFile', 'keysFile'],
      help: 'atSign\'s atKeys file if not in '
        '~/.atsign/keys/<@atSign>_key.atKeys'
    );

    argParser.addFlag(
      'verbose',
      abbr: 'v',
      defaultsTo: false,
      help: 'Extra logging',
    );
    return argParser;
  }

}

