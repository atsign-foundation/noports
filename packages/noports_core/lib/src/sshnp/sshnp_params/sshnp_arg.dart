import 'package:args/args.dart';

import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/types.dart';

enum ArgFormat {
  option,
  multiOption,
  flag,
}

enum ArgType {
  string,
  integer,
}

enum ParseWhen {
  always,
  commandLine,
  configFile,
  never,
}

const Map<ParserType, Set<ParseWhen>> _allowListMap = {
  ParserType.all: {
    ParseWhen.always,
    ParseWhen.commandLine,
    ParseWhen.configFile,
  },
  ParserType.commandLine: {ParseWhen.always, ParseWhen.commandLine},
  ParserType.configFile: {ParseWhen.always, ParseWhen.configFile},
};

enum ParserType {
  all,
  commandLine,
  configFile;

  Iterable<ParseWhen> get allowList => _allowListMap[this]!;

  Iterable<ParseWhen> get denyList =>
      ParseWhen.values.toSet().difference(allowList as Set);

  bool shouldParse(ParseWhen parseWhen) {
    return allowList.contains(parseWhen);
  }
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
  final ParseWhen parseWhen;
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
    this.parseWhen = ParseWhen.always,
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

  static final List<SSHNPArg> args = [
    profileNameArg,
    helpArg,
    keyFileArg,
    fromArg,
    toArg,
    deviceArg,
    hostArg,
    portArg,
    localPortArg,
    identityFileArg,
    identityPassphraseArg,
    sendSshPublicKeyArg,
    localSshOptionsArg,
    verboseArg,
    remoteUserNameArg,
    rootDomainArg,
    localSshdPortArg,
    legacyDaemonArg,
    remoteSshdPortArg,
    idleTimeoutArg,
    sshClientArg,
    ssHAlgorithmArg,
    addForwardsToTunnelArg,
    configFileArg,
    listDevicesArg,
  ];

  @override
  String toString() {
    return 'SSHNPArg{format: $format, name: $name, abbr: $abbr, help: $help, mandatory: $mandatory, defaultsTo: $defaultsTo, type: $type}';
  }

  static ArgParser createArgParser({
    ParserType parserType = ParserType.all,
    bool withDefaults = true,
    Iterable<String>? includeList,
    Iterable<String>? excludeList,
  }) {
    var parser = ArgParser();
    // Basic arguments
    for (SSHNPArg arg in SSHNPArg.args) {
      if (!parserType.shouldParse(arg.parseWhen)) {
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

  static const profileNameArg = SSHNPArg(
    name: 'profile-name',
    help: 'Name of the profile to use',
    parseWhen: ParseWhen.configFile,
  );
  static const helpArg = SSHNPArg(
    name: 'help',
    help: 'Print this usage information',
    defaultsTo: DefaultArgs.help,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
  );
  static const keyFileArg = SSHNPArg(
    name: 'key-file',
    abbr: 'k',
    help: 'Sending atSign\'s atKeys file if not in ~/.atsign/keys/',
    parseWhen: ParseWhen.commandLine,
  );
  static const fromArg = SSHNPArg(
    name: 'from',
    abbr: 'f',
    help: 'Sending (a.k.a. client) atSign',
    mandatory: true,
  );
  static const toArg = SSHNPArg(
    name: 'to',
    abbr: 't',
    help: 'Receiving device atSign',
    mandatory: true,
  );
  static const deviceArg = SSHNPArg(
    name: 'device',
    abbr: 'd',
    help: 'Receiving device name',
    defaultsTo: DefaultSSHNPArgs.device,
  );
  static const hostArg = SSHNPArg(
    name: 'host',
    abbr: 'h',
    help: 'atSign of sshrvd daemon or FQDN/IP address to connect back to',
    mandatory: true,
  );
  static const portArg = SSHNPArg(
    name: 'port',
    abbr: 'p',
    help:
        'TCP port to connect back to (only required if --host specified a FQDN/IP)',
    defaultsTo: DefaultSSHNPArgs.port,
    type: ArgType.integer,
  );
  static const localPortArg = SSHNPArg(
    name: 'local-port',
    abbr: 'l',
    help:
        'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port',
    defaultsTo: DefaultSSHNPArgs.localPort,
    type: ArgType.integer,
  );
  static const identityFileArg = SSHNPArg(
    name: 'identity-file',
    abbr: 'i',
    help: 'Identity file to use for ssh connection',
    parseWhen: ParseWhen.commandLine,
  );
  static const identityPassphraseArg = SSHNPArg(
    name: 'identity-passphrase',
    help: 'Passphrase for identity file',
    parseWhen: ParseWhen.commandLine,
  );
  static const sendSshPublicKeyArg = SSHNPArg(
    name: 'send-ssh-public-key',
    abbr: 's',
    help:
        'When true, the ssh public key will be sent to the remote host for use in the ssh session',
    defaultsTo: DefaultSSHNPArgs.sendSshPublicKey,
    format: ArgFormat.flag,
  );
  static const localSshOptionsArg = SSHNPArg(
    name: 'local-ssh-options',
    abbr: 'o',
    defaultsTo: DefaultSSHNPArgs.localSshOptions,
    help: 'Add these commands to the local ssh command',
    format: ArgFormat.multiOption,
  );
  static const verboseArg = SSHNPArg(
    name: 'verbose',
    abbr: 'v',
    defaultsTo: DefaultArgs.verbose,
    help: 'More logging',
    format: ArgFormat.flag,
  );
  static const remoteUserNameArg = SSHNPArg(
    name: 'remote-user-name',
    abbr: 'u',
    help: 'username to use in the ssh session on the remote host',
  );
  static const rootDomainArg = SSHNPArg(
    name: 'root-domain',
    help: 'atDirectory domain',
    defaultsTo: DefaultArgs.rootDomain,
    mandatory: false,
    format: ArgFormat.option,
  );
  static const localSshdPortArg = SSHNPArg(
    name: 'local-sshd-port',
    help: 'port on which sshd is listening locally on the client host',
    defaultsTo: DefaultArgs.localSshdPort,
    abbr: 'P',
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
  );
  static const legacyDaemonArg = SSHNPArg(
    name: 'legacy-daemon',
    help: 'Request is to a legacy (< 4.0.0) noports daemon',
    defaultsTo: DefaultSSHNPArgs.legacyDaemon,
    format: ArgFormat.flag,
  );
  static const remoteSshdPortArg = SSHNPArg(
    name: 'remote-sshd-port',
    help: 'port on which sshd is listening locally on the device host',
    defaultsTo: DefaultArgs.remoteSshdPort,
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
  );
  static const idleTimeoutArg = SSHNPArg(
    name: 'idle-timeout',
    help:
        'number of seconds after which inactive ssh connections will be closed',
    defaultsTo: DefaultArgs.idleTimeout,
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
    parseWhen: ParseWhen.commandLine,
  );
  static final sshClientArg = SSHNPArg(
    name: 'ssh-client',
    help: 'What to use for outbound ssh connections',
    defaultsTo: DefaultSSHNPArgs.sshClient.toString(),
    allowed: SupportedSshClient.values.map((c) => c.toString()).toList(),
    parseWhen: ParseWhen.commandLine,
  );
  static final ssHAlgorithmArg = SSHNPArg(
    name: 'ssh-algorithm',
    help: 'SSH algorithm to use',
    defaultsTo: DefaultArgs.sshAlgorithm.toString(),
    allowed: SupportedSSHAlgorithm.values.map((c) => c.toString()).toList(),
    parseWhen: ParseWhen.commandLine,
  );
  static const addForwardsToTunnelArg = SSHNPArg(
    name: 'add-forwards-to-tunnel',
    help: 'When true, any local forwarding directives provided in'
        '--local-ssh-options will be added to the initial tunnel ssh request',
    defaultsTo: DefaultArgs.addForwardsToTunnel,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
  );
  static const configFileArg = SSHNPArg(
    name: 'config-file',
    help:
        'Read args from a config file\nMandatory args are not required if already supplied in the config file',
    parseWhen: ParseWhen.commandLine,
  );
  static const listDevicesArg = SSHNPArg(
    name: 'list-devices',
    help: 'List available devices',
    defaultsTo: DefaultSSHNPArgs.listDevices,
    aliases: ['ls'],
    negatable: false,
    parseWhen: ParseWhen.commandLine,
  );
}
