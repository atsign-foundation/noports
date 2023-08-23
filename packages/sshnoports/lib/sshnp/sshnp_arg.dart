import 'sshnp.dart';

enum ArgFormat {
  option,
  multiOption,
  flag,
}

enum ArgType {
  string,
  integer,
}

class SSHNPArg {
  final ArgFormat format;

  final String name;
  final String? abbr;
  final String? help;
  final bool mandatory;
  final dynamic defaultsTo;
  final ArgType type;

  const SSHNPArg({
    required this.name,
    this.abbr,
    this.help,
    this.mandatory = false,
    this.format = ArgFormat.option,
    this.defaultsTo,
    this.type = ArgType.string,
  });

  String get bashName => name.replaceAll('-', '_').toUpperCase();

  factory SSHNPArg.noArg() {
    return SSHNPArg(name: '');
  }

  factory SSHNPArg.fromName(String name) {
    return args.firstWhere(
      (arg) => arg.name == name,
      orElse: () => SSHNPArg.noArg(),
    );
  }

  factory SSHNPArg.fromBashName(String bashName) {
    return args.firstWhere(
      (arg) => arg.bashName == bashName,
      orElse: () => SSHNPArg.noArg(),
    );
  }

  static List<SSHNPArg> args = [
    SSHNPArg(
      name: 'key-file',
      abbr: 'k',
      help: 'Sending atSign\'s atKeys file if not in ~/.atsign/keys/',
    ),
    SSHNPArg(
      name: 'from',
      abbr: 'f',
      help: 'Sending (a.k.a. client) atSign',
      mandatory: true,
    ),
    SSHNPArg(
      name: 'to',
      abbr: 't',
      help: 'Receiving device atSign',
      mandatory: true,
    ),
    SSHNPArg(
      name: 'device',
      abbr: 'd',
      help: 'Receiving device name',
      defaultsTo: SSHNP.defaultDevice,
    ),
    SSHNPArg(
      name: 'host',
      abbr: 'h',
      help: 'atSign of sshrvd daemon or FQDN/IP address to connect back to',
      mandatory: true,
    ),
    SSHNPArg(
      name: 'port',
      abbr: 'p',
      help:
          'TCP port to connect back to (only required if --host specified a FQDN/IP)',
      defaultsTo: SSHNP.defaultPort,
      type: ArgType.integer,
    ),
    SSHNPArg(
      name: 'local-port',
      abbr: 'l',
      help:
          'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port',
      defaultsTo: SSHNP.defaultLocalPort,
      type: ArgType.integer
    ),
    SSHNPArg(
      name: 'ssh-public-key',
      abbr: 's',
      help:
          'Public key file from ~/.ssh to be appended to authorized_hosts on the remote device',
      defaultsTo: SSHNP.defaultSendSshPublicKey,
    ),
    SSHNPArg(
      name: 'local-ssh-options',
      abbr: 'o',
      help: 'Add these commands to the local ssh command',
      format: ArgFormat.multiOption,
    ),
    SSHNPArg(
      name: 'verbose',
      abbr: 'v',
      defaultsTo: SSHNP.defaultVerbose,
      help: 'More logging',
      format: ArgFormat.flag,
    ),
    SSHNPArg(
      name: 'rsa',
      abbr: 'r',
      defaultsTo: SSHNP.defaultRsa,
      help: 'Use RSA 4096 keys rather than the default ED25519 keys',
      format: ArgFormat.flag,
    ),
    SSHNPArg(
      name: 'remote-user-name',
      abbr: 'u',
      help: 'username to use in the ssh session on the remote host',
    ),
    SSHNPArg(
      name: 'root-domain',
      help: 'atDirectory domain',
      defaultsTo: SSHNP.defaultRootDomain,
      mandatory: false,
      format: ArgFormat.option,
    ),
    SSHNPArg(
      name: 'local-sshd-port',
      help: 'port sshd is listening locally on localhost',
      defaultsTo: SSHNP.defaultLocalSshdPort,
      abbr: 'P',
      mandatory: false,
      format: ArgFormat.option,
      type: ArgType.integer,
    ),

    SSHNPArg(
      name: 'legacy-daemon',
      defaultsTo: SSHNP.defaultLegacyDaemon,
      help: 'Request is to a legacy (< 3.5.0) noports daemon',
      format: ArgFormat.flag,
    ),
  ];
}
