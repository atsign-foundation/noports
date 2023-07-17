import 'package:args/args.dart';
import 'package:sshnoports/common/utils.dart';

class SSHNPDParams {
  late final String device;
  late final String username;
  late final String homeDirectory;
  late final String managerAtsign;
  late final String atKeysFilePath;
  late final String sendSshPublicKey;
  late final String deviceAtsign;
  late final bool verbose;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SSHNPDParams.fromArgs(List<String> args) {
    // Arg check
    ArgResults r = parser.parse(args);

    // Do we have a username ?
    username = getUserName(throwIfNull: true)!;

    // Do we have a 'home' directory?
    homeDirectory = getHomeDirectory(throwIfNull: true)!;

    // Do we have a device ?
    device = r['device'];

    // Do we have an ASCII ?
    if (checkNonAscii(device)) {
      throw ('\nDevice name can only contain alphanumeric characters with a max length of 15');
    }

    deviceAtsign = r['atsign'];
    managerAtsign = r['manager'];
    atKeysFilePath =
        r['key-file'] ?? getDefaultAtKeysFilePath(homeDirectory, deviceAtsign);

    verbose = r['verbose'];
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser();

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this device',
    );
    parser.addOption(
      'manager',
      abbr: 'm',
      mandatory: true,
      help: 'Managers atSign, that this device will accept triggers from',
    );
    parser.addOption(
      'device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help:
          'Send a trigger to this device, allows multiple devices share an atSign',
    );

    parser.addFlag(
      'sshpublickey',
      abbr: 's',
      help: 'Update authorized_keys to include public key from sshnp',
    );
    parser.addFlag(
      'username',
      abbr: 'u',
      help:
          'Send username to the manager to allow sshnp to display username in command line',
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    return parser;
  }
}
