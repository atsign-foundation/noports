import 'package:args/args.dart';
import 'package:noports_core/src/common/supported_ssh_clients.dart';

import 'package:noports_core/src/common/default_args.dart';

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
  final Iterable<String>? allowed;
  final bool commandLineOnly;
  final List<String>? aliases;
  final bool negatable;
  final bool hide;

  const SSHNPArg({
    required this.name,
    this.abbr,
    this.help,
    this.mandatory = false,
    this.format = ArgFormat.option,
    this.defaultsTo,
    this.type = ArgType.string,
    this.allowed,
    this.commandLineOnly = false,
    this.aliases,
    this.negatable = true,
    this.hide = false,
  });

  String get bashName => name.replaceAll('-', '_').toUpperCase();

  List<String> get aliasList =>
      ['--$name', ...aliases?.map((e) => '--$e') ?? [], '-$abbr'];

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
    const SSHNPArg(
      name: 'help',
      help: 'Print this usage information',
      defaultsTo: DefaultArgs.help,
      format: ArgFormat.flag,
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'key-file',
      abbr: 'k',
      help: 'Sending atSign\'s atKeys file if not in ~/.atsign/keys/',
    ),
    const SSHNPArg(
      name: 'from',
      abbr: 'f',
      help: 'Sending (a.k.a. client) atSign',
      mandatory: true,
    ),
    const SSHNPArg(
      name: 'to',
      abbr: 't',
      help: 'Receiving device atSign',
      mandatory: true,
    ),
    const SSHNPArg(
      name: 'device',
      abbr: 'd',
      help: 'Receiving device name',
      defaultsTo: DefaultSSHNPArgs.device,
    ),
    const SSHNPArg(
      name: 'host',
      abbr: 'h',
      help: 'atSign of sshrvd daemon or FQDN/IP address to connect back to',
      mandatory: true,
    ),
    const SSHNPArg(
      name: 'port',
      abbr: 'p',
      help:
          'TCP port to connect back to (only required if --host specified a FQDN/IP)',
      defaultsTo: DefaultSSHNPArgs.port,
      type: ArgType.integer,
    ),
    const SSHNPArg(
      name: 'local-port',
      abbr: 'l',
      help:
          'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port',
      defaultsTo: DefaultSSHNPArgs.localPort,
      type: ArgType.integer,
    ),
    const SSHNPArg(
      name: 'identity-file',
      abbr: 'i',
      help: 'Identity file to use for ssh connection',
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'identity-passphrase',
      help: 'Passphrase for identity file',
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'send-ssh-public-key',
      abbr: 's',
      help:
          'When true, the ssh public key will be sent to the remote host for use in the ssh session',
      defaultsTo: DefaultSSHNPArgs.sendSshPublicKey,
      format: ArgFormat.flag,
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'local-ssh-options',
      abbr: 'o',
      help: 'Add these commands to the local ssh command',
      format: ArgFormat.multiOption,
    ),
    const SSHNPArg(
      name: 'verbose',
      abbr: 'v',
      defaultsTo: DefaultArgs.verbose,
      help: 'More logging',
      format: ArgFormat.flag,
    ),
    const SSHNPArg(
      name: 'rsa',
      abbr: 'r',
      defaultsTo: DefaultArgs.rsa,
      help: 'Use RSA 4096 keys rather than the default ED25519 keys',
      format: ArgFormat.flag,
    ),
    const SSHNPArg(
      name: 'remote-user-name',
      abbr: 'u',
      help: 'username to use in the ssh session on the remote host',
    ),
    const SSHNPArg(
      name: 'root-domain',
      help: 'atDirectory domain',
      defaultsTo: DefaultArgs.rootDomain,
      mandatory: false,
      format: ArgFormat.option,
    ),
    const SSHNPArg(
      name: 'local-sshd-port',
      help: 'port on which sshd is listening locally on the client host',
      defaultsTo: DefaultArgs.localSshdPort,
      abbr: 'P',
      mandatory: false,
      format: ArgFormat.option,
      type: ArgType.integer,
    ),
    const SSHNPArg(
      name: 'legacy-daemon',
      defaultsTo: DefaultSSHNPArgs.legacyDaemon,
      help: 'Request is to a legacy (< 4.0.0) noports daemon',
      format: ArgFormat.flag,
    ),
    const SSHNPArg(
      name: 'remote-sshd-port',
      help: 'port on which sshd is listening locally on the device host',
      defaultsTo: DefaultArgs.remoteSshdPort,
      mandatory: false,
      format: ArgFormat.option,
      type: ArgType.integer,
    ),
    const SSHNPArg(
      name: 'idle-timeout',
      help:
          'number of seconds after which inactive ssh connections will be closed',
      defaultsTo: DefaultArgs.idleTimeout,
      mandatory: false,
      format: ArgFormat.option,
      type: ArgType.integer,
      commandLineOnly: true,
    ),
    SSHNPArg(
      name: 'ssh-client',
      help: 'What to use for outbound ssh connections',
      defaultsTo: SupportedSshClient.exec.cliArg,
      mandatory: false,
      format: ArgFormat.option,
      type: ArgType.string,
      allowed: SupportedSshClient.values.map((c) => c.cliArg).toList(),
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'ssh-key-pair-pem',
      help: 'The pem file contents of the ssh key pair',
      commandLineOnly: true,
      format: ArgFormat.option,
      hide: true,
    ),
    const SSHNPArg(
      name: 'add-forwards-to-tunnel',
      defaultsTo: false,
      help: 'When true, any local forwarding directives provided in'
          '--local-ssh-options will be added to the initial tunnel ssh request',
      format: ArgFormat.flag,
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'config-file',
      help:
          'Read args from a config file\nMandatory args are not required if already supplied in the config file',
      commandLineOnly: true,
    ),
    const SSHNPArg(
      name: 'list-devices',
      aliases: ['ls'],
      negatable: false,
      help: 'List available devices',
      commandLineOnly: true,
    ),
  ];

  @override
  String toString() {
    return 'SSHNPArg{format: $format, name: $name, abbr: $abbr, help: $help, mandatory: $mandatory, defaultsTo: $defaultsTo, type: $type}';
  }

  static ArgParser createArgParser({
    bool isCommandLine = true,
    bool withDefaults = true,
    Iterable<String>? includeList,
  }) {
    var parser = ArgParser();
    // Basic arguments
    for (SSHNPArg arg in SSHNPArg.args) {
      if (includeList != null && !includeList.contains(arg.name)) {
        continue;
      }
      if (arg.commandLineOnly && !isCommandLine) {
        continue;
      }
      switch (arg.format) {
        case ArgFormat.option:
          parser.addOption(
            arg.name,
            abbr: arg.abbr,
            mandatory: arg.mandatory,
            defaultsTo: withDefaults ? arg.defaultsTo?.toString() : null,
            help: arg.help,
            hide: arg.hide,
            allowed: arg.allowed,
            aliases: arg.aliases ?? const [],
          );
          break;
        case ArgFormat.multiOption:
          parser.addMultiOption(
            arg.name,
            abbr: arg.abbr,
            defaultsTo: withDefaults ? arg.defaultsTo as List<String>? : null,
            help: arg.help,
            hide: arg.hide,
          );
          break;
        case ArgFormat.flag:
          parser.addFlag(
            arg.name,
            abbr: arg.abbr,
            defaultsTo: withDefaults ? arg.defaultsTo as bool? : null,
            help: arg.help,
            hide: arg.hide,
            negatable: arg.negatable,
          );
          break;
      }
    }
    return parser;
  }
}
