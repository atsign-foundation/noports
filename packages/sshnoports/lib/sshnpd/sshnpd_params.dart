part of 'sshnpd.dart';

class SSHNPDParams {
  late final String device;
  late final String username;
  late final String homeDirectory;
  late final String managerAtsign;
  late final String atKeysFilePath;
  late final String sendSshPublicKey;
  late final String deviceAtsign;
  late final bool verbose;
  late final bool makeDeviceInfoVisible;
  late final bool addSshPublicKeys;
  late final SupportedSshClient sshClient;
  late final String rootDomain;
  late final int localSshdPort;
  late final String ephemeralPermissions;
  late final bool rsa;

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

    sshClient = SupportedSshClient.values
        .firstWhere((c) => c.cliArg == r['ssh-client']);

    rootDomain = r['root-domain'];

    makeDeviceInfoVisible = r['un-hide'];

    addSshPublicKeys = r['sshpublickey'];

    localSshdPort =
        int.tryParse(r['local-sshd-port']) ?? defaults.defaultLocalSshdPort;

    ephemeralPermissions = r['ephemeral-permissions'];

    rsa = r['rsa'];
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
      defaultsTo: false,
      help:
          'When set, will update authorized_keys to include public key sent by manager',
    );
    parser.addFlag(
      'un-hide',
      abbr: 'u',
      aliases: const ['username'],
      defaultsTo: false,
      help:
          'When set, makes various information visible to the manager atSign - e.g. username, version, etc',
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );

    parser.addOption('ssh-client',
        mandatory: false,
        defaultsTo: SupportedSshClient.hostSsh.cliArg,
        allowed: SupportedSshClient.values.map((c) => c.cliArg).toList(),
        help: 'What to use for outbound ssh connections.');

    parser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );

    parser.addOption(
      'local-sshd-port',
      help: 'port on which sshd is listening locally on localhost',
      defaultsTo: defaults.defaultLocalSshdPort.toString(),
      mandatory: false,
    );

    parser.addOption('ephemeral-permissions',
        help: 'The permissions which will be added to the authorized_keys file'
            ' for the ephemeral public keys which are generated when a client'
            ' is connecting via forward ssh'
            ' e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"',
        defaultsTo: '',
        mandatory: false);

    parser.addFlag(
      'rsa',
      abbr: 'r',
      defaultsTo: defaults.defaultRsa,
      help: 'Use RSA 4096 keys rather than the default ED25519 keys',
    );

    return parser;
  }
}
