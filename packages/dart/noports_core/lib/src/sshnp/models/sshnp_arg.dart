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

class SshnpArg {
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

  const SshnpArg({
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

  factory SshnpArg.noArg() {
    return SshnpArg(name: '');
  }

  factory SshnpArg.fromName(String name) {
    return args.firstWhere(
      (arg) => arg.name == name,
      orElse: () => SshnpArg.noArg(),
    );
  }

  factory SshnpArg.fromBashName(String bashName) {
    return args.firstWhere(
      (arg) => arg.bashName == bashName,
      orElse: () => SshnpArg.noArg(),
    );
  }

  static final List<SshnpArg> args = [
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
    tunnelUserNameArg,
    rootDomainArg,
    localSshdPortArg,
    remoteSshdPortArg,
    idleTimeoutArg,
    sshAlgorithmArg,
    addForwardsToTunnelArg,
    configFileArg,
    listDevicesArg,
    authenticateClientToRvdArg,
    authenticateDeviceToRvdArg,
    encryptRvdTrafficArg,
    discoverDaemonFeaturesArg,
  ];

  @override
  String toString() {
    return 'SshnpArg{format: $format, name: $name, abbr: $abbr, help: $help, mandatory: $mandatory, defaultsTo: $defaultsTo, type: $type}';
  }

  static final disabledArgs = [
    portArg,
    localSshdPortArg,
  ];

  static ArgParser createArgParser({
    ParserType parserType = ParserType.all,
    bool withDefaults = true,
    Iterable<String>? includeList,
    Iterable<String>? excludeList,
    int? usageLineLength,
  }) {
    var parser = ArgParser(usageLineLength: usageLineLength);
    // Basic arguments
    for (SshnpArg arg in SshnpArg.args) {
      if (!parserType.shouldParse(arg.parseWhen) ||
          disabledArgs.contains(arg)) {
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
            aliases: arg.aliases ?? const [],
          );
          break;
      }
    }
    return parser;
  }

  static const profileNameArg = SshnpArg(
    name: 'profile-name',
    help: 'Name of the profile to use',
    parseWhen: ParseWhen.configFile,
  );
  static const helpArg = SshnpArg(
    name: 'help',
    help: 'Print this usage information',
    defaultsTo: DefaultArgs.help,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    negatable: false,
  );
  static const keyFileArg = SshnpArg(
    name: 'key-file',
    abbr: 'k',
    help: 'Sending atSign\'s atKeys file if not in ~/.atsign/keys/',
    parseWhen: ParseWhen.commandLine,
  );
  static const fromArg = SshnpArg(
    name: 'from',
    abbr: 'f',
    help: 'Sending (a.k.a. client) atSign',
    mandatory: true,
  );
  static const toArg = SshnpArg(
    name: 'to',
    abbr: 't',
    help: 'Receiving device atSign',
    mandatory: true,
  );
  static const deviceArg = SshnpArg(
    name: 'device',
    abbr: 'd',
    help: 'Receiving device name',
    defaultsTo: DefaultSshnpArgs.device,
  );
  static const hostArg = SshnpArg(
    name: 'host',
    abbr: 'h',
    help: 'atSign of srvd daemon or FQDN/IP address to connect back to',
    mandatory: true,
  );
  static const portArg = SshnpArg(
    name: 'port',
    abbr: 'p',
    help:
        'TCP port to connect back to (only required if --host specified a FQDN/IP)',
    defaultsTo: DefaultSshnpArgs.port,
    type: ArgType.integer,
  );
  static const localPortArg = SshnpArg(
    name: 'local-port',
    abbr: 'l',
    help:
        'Reverse ssh port to listen on, on your local machine, by sshnp default finds a spare port',
    defaultsTo: DefaultSshnpArgs.localPort,
    type: ArgType.integer,
  );
  static const identityFileArg = SshnpArg(
    name: 'identity-file',
    abbr: 'i',
    help: 'Identity file to use for ssh connection',
    parseWhen: ParseWhen.commandLine,
  );
  static const identityPassphraseArg = SshnpArg(
    name: 'identity-passphrase',
    help: 'Passphrase for identity file',
    parseWhen: ParseWhen.commandLine,
  );
  static const sendSshPublicKeyArg = SshnpArg(
    name: 'send-ssh-public-key',
    abbr: 's',
    help:
        'When true, the ssh public key will be sent to the remote host for use in the ssh session',
    defaultsTo: DefaultSshnpArgs.sendSshPublicKey,
    format: ArgFormat.flag,
    negatable: false,
  );
  static const localSshOptionsArg = SshnpArg(
    name: 'local-ssh-options',
    abbr: 'o',
    defaultsTo: DefaultSshnpArgs.localSshOptions,
    help: 'Add these commands to the local ssh command',
    format: ArgFormat.multiOption,
  );
  static const verboseArg = SshnpArg(
    name: 'verbose',
    abbr: 'v',
    defaultsTo: DefaultArgs.verbose,
    help: 'More logging',
    format: ArgFormat.flag,
    negatable: false,
  );
  static const remoteUserNameArg = SshnpArg(
    name: 'remote-user-name',
    abbr: 'u',
    help: 'username to use in the ssh session on the remote host',
  );
  static const tunnelUserNameArg = SshnpArg(
    name: 'tunnel-user-name',
    abbr: 'U',
    help: 'username to use for the initial ssh tunnel',
  );
  static const rootDomainArg = SshnpArg(
    name: 'root-domain',
    help: 'atDirectory domain',
    defaultsTo: DefaultArgs.rootDomain,
    mandatory: false,
    format: ArgFormat.option,
  );
  static const localSshdPortArg = SshnpArg(
    name: 'local-sshd-port',
    help: 'port on which sshd is listening locally on the client host',
    defaultsTo: DefaultArgs.localSshdPort,
    abbr: 'P',
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
  );
  static const remoteSshdPortArg = SshnpArg(
    name: 'remote-sshd-port',
    help: 'port on which sshd is listening locally on the device host',
    defaultsTo: DefaultArgs.remoteSshdPort,
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
  );
  static const idleTimeoutArg = SshnpArg(
    name: 'idle-timeout',
    help:
        'number of seconds after which inactive ssh connections will be closed',
    defaultsTo: DefaultArgs.idleTimeout,
    mandatory: false,
    format: ArgFormat.option,
    type: ArgType.integer,
    parseWhen: ParseWhen.commandLine,
  );
  static final sshAlgorithmArg = SshnpArg(
    name: 'ssh-algorithm',
    help: 'SSH algorithm to use',
    defaultsTo: DefaultArgs.sshAlgorithm.toString(),
    allowed: SupportedSshAlgorithm.values.map((c) => c.toString()).toList(),
    parseWhen: ParseWhen.commandLine,
  );
  static const addForwardsToTunnelArg = SshnpArg(
    name: 'add-forwards-to-tunnel',
    help: 'When true, any local forwarding directives provided in'
        '--local-ssh-options will be added to the initial tunnel ssh request',
    defaultsTo: DefaultArgs.addForwardsToTunnel,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    negatable: false,
  );
  static const configFileArg = SshnpArg(
    name: 'config-file',
    help:
        'Read args from a config file\nMandatory args are not required if already supplied in the config file',
    parseWhen: ParseWhen.commandLine,
  );
  static const listDevicesArg = SshnpArg(
    name: 'list-devices',
    help: 'List available devices',
    defaultsTo: DefaultSshnpArgs.listDevices,
    format: ArgFormat.flag,
    aliases: ['ls'],
    negatable: false,
    parseWhen: ParseWhen.commandLine,
  );
  static const authenticateClientToRvdArg = SshnpArg(
    name: 'authenticate-client-to-rvd',
    aliases: ['ac'],
    help: 'When false, client will not authenticate itself to rvd',
    defaultsTo: DefaultArgs.authenticateClientToRvd,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    mandatory: false,
  );
  static const authenticateDeviceToRvdArg = SshnpArg(
    name: 'authenticate-device-to-rvd',
    aliases: ['ad'],
    help: 'When false, device will not authenticate to the socket rendezvous',
    defaultsTo: DefaultArgs.authenticateDeviceToRvd,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    mandatory: false,
  );
  static const encryptRvdTrafficArg = SshnpArg(
    name: 'encrypt-rvd-traffic',
    aliases: ['et'],
    help: 'When true, traffic via the socket rendezvous is encrypted,'
        ' in addition to whatever encryption the traffic already has'
        ' (e.g. an ssh session)',
    defaultsTo: DefaultArgs.encryptRvdTraffic,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    mandatory: false,
  );
  static const discoverDaemonFeaturesArg = SshnpArg(
    name: 'discover-daemon-features',
    aliases: ['ddf'],
    help: 'When this flag is set, this client starts by pinging the daemon to'
        ' discover what features it supports, and exits if this client has '
        ' requested use of a feature which the daemon does not support.'
        ' If you already know what features the daemon supports and are '
        ' setting other flags (--authenticate-device-to-rvd and'
        ' --encrypt-rvd-traffic) based on that knowledge, then you should unset'
        ' this flag to reduce total time-to-connection.',
    defaultsTo: DefaultArgs.discoverDaemonFeatures,
    format: ArgFormat.flag,
    parseWhen: ParseWhen.commandLine,
    mandatory: false,
    negatable: false,
  );
}
