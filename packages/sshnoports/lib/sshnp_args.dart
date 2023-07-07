enum ArgFormat {
  option,
  multiOption,
  flag,
}

class SSHNPArg {
  final ArgFormat format;

  final String name;
  final String? abbr;
  final String? help;
  final bool mandatory;
  final dynamic defaultsTo;

  const SSHNPArg({
    required this.name,
    this.abbr,
    this.help,
    this.mandatory = false,
    this.format = ArgFormat.option,
    this.defaultsTo,
  });

  String get bashName => name.replaceAll('-', '_').toUpperCase();

  factory SSHNPArg.noArg() {
    return SSHNPArg(name: '');
  }

  factory SSHNPArg.fromName(String name) {
    return sshnpArgs.firstWhere(
      (arg) => arg.name == name,
      orElse: () => SSHNPArg.noArg(),
    );
  }

  factory SSHNPArg.fromBashName(String bashName) {
    return sshnpArgs.firstWhere(
      (arg) => arg.bashName == bashName,
      orElse: () => SSHNPArg.noArg(),
    );
  }
}

List<SSHNPArg> sshnpArgs = [
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
    defaultsTo: "default",
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
    defaultsTo: '22',
  ),
  SSHNPArg(
    name: 'local-port',
    abbr: 'l',
    help:
        'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port',
    defaultsTo: '0',
  ),
  SSHNPArg(
    name: 'ssh-public-key',
    abbr: 's',
    help:
        'Public key file from ~/.ssh to be appended to authorized_hosts on the remote device',
    defaultsTo: 'false',
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
    defaultsTo: false,
    help: 'More logging',
    format: ArgFormat.flag,
  ),
  SSHNPArg(
    name: 'rsa',
    abbr: 'r',
    defaultsTo: false,
    help: 'Use RSA 4096 keys rather than the default ED25519 keys',
    format: ArgFormat.flag,
  ),
  SSHNPArg(
    name: 'remote-user-name',
    abbr: 'u',
    help: 'username to use in the ssh session on the remote host',
  ),
];
