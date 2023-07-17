import 'package:args/args.dart';
import 'package:sshnoports/common/utils.dart';

class SSHRVDParams {
  late final String username;
  late final String atSign;
  late final String homeDirectory;
  late final String atKeysFilePath;
  late final String managerAtsign;
  late final String ipAddress;
  late final bool verbose;
  late final bool snoop;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SSHRVDParams.fromArgs(List<String> args) {
    // Arg check
    ArgResults r = parser.parse(args);

    // Do we have a username ?
    username = getUserName(throwIfNull: true)!;

    // Do we have a 'home' directory?
    homeDirectory = getHomeDirectory(throwIfNull: true)!;

    atSign = r['atsign'];
    managerAtsign = r['manager'];
    atKeysFilePath =
        r['keyFile'] ?? getDefaultAtKeysFilePath(homeDirectory, atSign);

    ipAddress = r['ip'];

    verbose = r['verbose'];
    snoop = r['snoop'];
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser();

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      help: 'atSign\'s atKeys file if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign for sshrvd',
    );
    parser.addOption(
      'manager',
      abbr: 'm',
      defaultsTo: 'open',
      mandatory: false,
      help:
          'Managers atSign that sshrvd will accept requests from. Default is any atSign can use sshrvd',
    );
    parser.addOption(
      'ip',
      abbr: 'i',
      mandatory: true,
      help: 'FQDN/IP address sent to clients',
    );

    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    parser.addFlag(
      'snoop',
      abbr: 's',
      defaultsTo: false,
      help: 'Snoop on traffic passing through service',
    );
    return parser;
  }
}
