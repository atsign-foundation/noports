import 'package:args/args.dart';
import 'package:noports_core/src/common/file_system_utils.dart';

class SSHNPAParams {
  final String authorizerAtsign;
  final Set<String> daemonAtsigns;
  final String atKeysFilePath;
  final bool verbose;
  final String rootDomain;
  final String homeDirectory;

  // Non param variables
  static final ArgParser parser = _createArgParser();
  SSHNPAParams({
    required this.authorizerAtsign,
    required this.daemonAtsigns,
    required this.atKeysFilePath,
    required this.verbose,
    required this.rootDomain,
    required this.homeDirectory,
  });

  static Future<SSHNPAParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String authorizerAtsign = r['atsign'];
    String homeDirectory = getHomeDirectory()!;

    return SSHNPAParams(
      authorizerAtsign: authorizerAtsign,
      daemonAtsigns: r['daemon-atsigns'].toString().split(',').toSet(),
      atKeysFilePath: r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, authorizerAtsign),
      verbose: r['verbose'],
      rootDomain: r['root-domain'],
      homeDirectory: homeDirectory,
    );
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser();

    // Basic arguments
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this authorizer',
    );

    parser.addOption(
      'daemon-atsigns',
      mandatory: true,
      help:
          'Comma-separated list of daemon atSigns which use this authorizer',
    );

    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/',
    );

    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    parser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );

    return parser;
  }
}
