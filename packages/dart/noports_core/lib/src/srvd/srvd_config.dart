import 'dart:io';

import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/config/file.dart';

const OptionGroup networkGroup = OptionGroup("Network Options");
const OptionGroup runtimeGroup = OptionGroup("Runtime Options");

enum SrvdOption<V> implements OptionDefinition<V> {
  // Config must be the first option otherwise this errors
  configFile(
    FileOption(
      argName: "config",
      envName: "SSHNPD_CONFIG",
      helpText: "The path to a config file",
      fromDefault: defaultConfigFilePath<SrvdParams>,
      mandatory: false,
    ),
  ),

  // atSign Options Group
  atsign(SharedOptions.atsign),
  rootServer(SharedOptions.rootServer),
  keyfile(SharedOptions.keyfile),
  storagePath(SharedOptions.storagePath),
  passPhrase(SharedOptions.passPhrase),

  manager(
    StringOption(
      argName: 'manager',
      configKey: '/access/managers',
      argAliases: ['manager'],
      argAbbrev: 'm',
      mandatory: false,
      helpText:
          'Manager atSign that srvd will accept requests from. Default is any atSign can use srvd',
      group: SharedOptions.atsignGroup,
    ),
  ),

  ipAddress(
    StringOption(
      argName: 'ip',
      configKey: '/network/ip',
      argAliases: ['ip'],
      argAbbrev: 'i',
      mandatory: true,
      helpText: 'FQDN/IP address sent to clients',
      group: networkGroup,
    ),
  ),

  bindPort(
    IntOption(
      argName: 'bindPort',
      configKey: '/network/443-bind-port',
      argAliases: ['443-bind-port'],
      mandatory: false,
      defaultsTo: 443,
      helpText:
          'The actual port to bind to - for example in a docker env you may wish to forward port 443 on the host to a different port in the container',
      min: 1,
      max: 65535,
      group: networkGroup,
    ),
  ),

  bind443(
    FlagOption(
      argName: 'bind443',
      configKey: '/network/bind-443',
      argAliases: ['443'],
      mandatory: false,
      defaultsTo: false,
      helpText:
          'Also bind to port 443, to support clients which want to conect only to port 443 (for ... \$reasons)',
      group: networkGroup,
    ),
  ),

  logTraffic(
    FlagOption(
      argName: 'logTraffic',
      configKey: '/runtime/log-traffic',
      mandatory: false,
      defaultsTo: true,
      helpText: 'log traffic',
      group: runtimeGroup,
    ),
  ),

  perSessionStorage(
    FlagOption(
      argName: 'perSessionStorage',
      configKey: '/runtime/per-session-storage',
      mandatory: false,
      defaultsTo: true,
      helpText:
          'Use ephermeral local storage for each session. When true, allows you to run multiple srvds concurrently on the same host, as the same user. When false, only a single local srvd may run concurrently on the same host as the same user. Alias --pss.'
          'defaults to on.',
      group: runtimeGroup,
    ),
  ),

  verbose(SharedOptions.verbose),
  debug(SharedOptions.debug),
  help(SharedOptions.help),
  version(SharedOptions.version);

  const SrvdOption(this.option);

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

class SrvdConfigBroker implements ConfigurationBroker {
  ({ConfigurationSource? config})? _cached;

  @override
  Object? valueOrNull(String key, Configuration<OptionDefinition> cfg) {
    if (_cached == null) {
      var file = cfg.value(SrvdOption.configFile);
      _cached ??= (
        config: file.existsSync()
            ? ConfigurationParser.fromFile(file.path)
            : null,
      );
    }
    var value = _cached?.config?.valueOrNull(key);
    return value;
  }
}
