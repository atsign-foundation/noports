import 'dart:io';

import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:yaml/yaml.dart';

import '../config/shared_options.dart';

const OptionGroup deviceConfigGroup = OptionGroup(
  "Device Configuration Options",
);
const OptionGroup accessControlGroup = OptionGroup("Access Control Options");
const OptionGroup sshGroup = OptionGroup("Sshd Configuration Options");

File _defaultConfigFilePath() {
  switch (Platform.operatingSystem) {
    case "windows":
      final programData = Platform.environment['ProgramData'];
      return File("$programData/NoPorts/sshnpd.yaml");
    case "macos":
      return File("/Library/Application Support/NoPorts/sshnpd.yaml");
    default:
      return File("/etc/noports/sshnpd.yaml");
  }
}

enum SshnpdOption<V> implements OptionDefinition<V> {
  // Config must be the first option otherwise this errors
  configFile(
    FileOption(
      argName: "config",
      envName: "SSHNPD_CONFIG",
      helpText: "The path to a config file",
      fromDefault: _defaultConfigFilePath,
      mandatory: false,
      mode: PathExistMode.mayExist,
      group: SharedOptions.runtimeGroup,
    ),
  ),

  // atSign Options Group
  keyfile(SharedOptions.keyfile),
  passPhrase(SharedOptions.passPhrase),
  atsign(SharedOptions.atsign),
  rootServer(SharedOptions.rootServer),

  // Access Control Group
  managers(
    MultiStringOption(
      argName: 'managers',
      configKey: '/access/managers',
      argAliases: ['manager'],
      argAbbrev: 'm',
      mandatory: false,
      helpText:
          'atSign or list of atSigns (comma separated)'
          ' that this device will accept requests from.'
          ' At least one of --managers and --policy-manager must be supplied.'
          ' If both --managers and --policy-manager are supplied then '
          ' the daemon will check with the --policy-manager atSign re '
          ' requests which come from atSigns not in the --managers list.',
      group: accessControlGroup,
    ),
  ),

  policyManager(
    StringOption(
      argName: 'policy-manager',
      configKey: '/access/policy',
      argAbbrev: 'p',
      mandatory: false,
      helpText:
          'The atSign which this device will use to decide whether or not to '
          ' accept requests from some client atSign. '
          ' At least one of --managers and --policy-manager must be supplied.'
          ' If both --managers and --policy-manager are supplied then '
          ' the daemon will check with the --policy-manager atSign re '
          ' requests which come from atSigns not in the --managers list.',
      group: accessControlGroup,
    ),
  ),

  permitOpen(
    MultiStringOption(
      argName: 'permit-open',
      configKey: '/access/permitopen',
      argAliases: ['po'],
      mandatory: false,
      helpText:
          'Comma separated-list of host:port to which the daemon will permit'
          ' a connection from an authorized client. Hosts may be dns names or'
          ' ip addresses.'
          ' Alias: --po',
      group: accessControlGroup,
    ),
  ),

  // Device Configuration Group
  device(
    StringOption(
      argName: 'device',
      configKey: '/device/name',
      argAbbrev: 'd',
      mandatory: false,
      defaultsTo: "default",
      helpText:
          'This daemon will operate with this device name;'
          ' allows multiple devices to share an atSign.',
      group: deviceConfigGroup,
    ),
  ),

  deviceGroup(
    StringOption(
      argName: 'device-group',
      configKey: '/device/group',
      argAliases: ['dg'],
      mandatory: false,
      defaultsTo: DefaultSshnpdArgs.deviceGroupName,
      helpText:
          'The name of this device\'s group. When delegated authorization'
          ' is being used then the group name is sent to the authorizer'
          ' service as well as the device name, this daemon\'s atSign, '
          ' and the client atSign which is requesting a connection.'
          ' Alias: --dg',
      group: deviceConfigGroup,
    ),
  ),

  hide(
    FlagOption(
      argName: 'hide',
      configKey: '/device/hide',
      argAbbrev: 'h',
      defaultsTo: false,
      helpText:
          'Hides the device from advertising its information to the manager'
          ' atSign. Even with this enabled, sshnpd will still respond to ping'
          ' requests from the manager. (This takes priority over -u / --un-hide)',
      group: deviceConfigGroup,
    ),
  ),

  unHide(
    FlagOption(
      argName: 'un-hide',
      argAbbrev: 'u',
      argAliases: ['username'],
      defaultsTo: true,
      hide: true,
      group: deviceConfigGroup,
    ),
  ),

  // Sshd Configuration Group
  addSshPublicKey(
    FlagOption(
      argName: 'sshpublickey',
      configKey: '/ssh/add-publickeys',
      argAbbrev: 's',
      defaultsTo: false,
      helpText:
          'When set, will update authorized_keys'
          ' to include public key sent by manager',
      group: sshGroup,
    ),
  ),

  sshClient(
    EnumOption(
      enumParser: EnumParser(SupportedSshClient.values),
      argName: 'ssh-client',
      configKey: '/ssh/client',
      mandatory: false,
      defaultsTo: DefaultSshnpdArgs.sshClient,
      helpText: 'What to use for outbound ssh connections.',
      group: sshGroup,
    ),
  ),

  localSshdPort(
    IntOption(
      argName: 'local-sshd-port',
      configKey: '/ssh/sshd-port',
      mandatory: false,
      defaultsTo: DefaultSshnpdArgs.localSshdPort,
      helpText: 'port on which sshd is listening locally on localhost',
      min: 1,
      max: 65535,
      group: sshGroup,
    ),
  ),

  sshPublicKeyPermissions(
    MultiStringOption(
      argName: 'sshpublickey-permissions',
      configKey: '/ssh/publickey-permissions',
      argAbbrev: 'S',
      defaultsTo: [],
      helpText:
          'When --sshpublickey is enabled, will include the specified permissions'
          ' in the public key entry in authorized_keys',
      group: sshGroup,
    ),
  ),

  sshEphemeralPermissions(
    MultiStringOption(
      argName: 'ephemeral-permissions',
      configKey: '/ssh/ephemeral-permissions',
      mandatory: false,
      defaultsTo: [],
      helpText:
          'The permissions which will be added to the authorized_keys file'
          ' for the ephemeral public keys which are generated when a client'
          ' is connecting via forward ssh'
          ' e.g. PermitOpen="host-1:3389",PermitOpen="localhost:80"',
      group: sshGroup,
    ),
  ),

  sshAlgorithm(
    EnumOption(
      enumParser: EnumParser(SupportedSshAlgorithm.values),
      argName: 'ssh-algorithm',
      configKey: '/ssh/algorithm',
      defaultsTo: DefaultArgs.sshAlgorithm,
      helpText: 'Use RSA 4096 keys rather than the default ED25519 keys',
      group: sshGroup,
    ),
  ),

  // Runtime Options
  storagePath(SharedOptions.storagePath),
  verbose(SharedOptions.verbose),
  debug(SharedOptions.debug),
  help(SharedOptions.help),
  version(SharedOptions.version),

  clearCachedPks(
    FlagOption(
      argName: 'clear-cached-pks',
      configKey: '/runtime/clear-cached-pks',
      helpText: 'Clear cached public keys',
      hide: true,
      defaultsTo: false,
      group: SharedOptions.runtimeGroup,
    ),
  ),

  strict(
    FlagOption(
      argName: 'strict',
      configKey: '/runtime/strict',
      helpText:
          'Explicitly set strict request verification. By default,'
          ' strict mode is only enabled when using a policy service. NOTE: If'
          ' strict mode is enabled when you are not using a policy service'
          ' then, if a requesting atSign\'s public key has changed since a'
          ' previous request was handled, the request will be rejected.',
      hide: false,
      defaultsTo: null,
      group: SharedOptions.runtimeGroup,
    ),
  ),

  doctor(
    FlagOption(
      argName: 'doctor',
      defaultsTo: false,
      helpText: 'Run the doctor',
      group: SharedOptions.runtimeGroup,
    ),
  ),

  output(
    FlagOption(
      argName: 'output',
      argAbbrev: 'o',
      defaultsTo: false,
      helpText:
          'Save doctor report to a file. Only valid when used with --doctor.'
          ' Defaults to sshnpd_doctor_log.txt.'
          ' A custom filename can be provided as an additional argument.',
      group: SharedOptions.runtimeGroup,
    ),
  );

  const SshnpdOption(this.option);

  @override
  final ConfigOptionBase<V> option;

  static ArgParser get argParser {
    final parser = ArgParser(
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
    );
    values.prepareForParsing(parser);
    return parser;
  }

  static String get usage => argParser.usage;
}

class SshnpdConfigBroker implements ConfigurationBroker {
  ({ConfigurationSource? config})? _cached;

  @override
  Object? valueOrNull(String key, Configuration<OptionDefinition> cfg) {
    if (_cached == null) {
      var file = cfg.value(SshnpdOption.configFile);
      _cached ??= (
        config: file.existsSync()
            ? ConfigurationParser.fromFile(file.path)
            : null,
      );
    }
    var value = _cached?.config?.valueOrNull(key);
    switch (key) {
      case '/access/managers':
      case '/access/permitopen':
      case '/ssh/publickey-permissions':
      case '/ssh/ephemeral-permissions':
        if (value is YamlList) {
          value = List.from(value);
        }
        if (value is List<dynamic>) {
          value = value.cast<String>();
        }
    }
    return value;
  }
}
