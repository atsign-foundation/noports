import 'dart:io';

import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/config/file.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/npa/npa_params.dart';

const OptionGroup npaEventsGroup = OptionGroup('Event Options');
const OptionGroup npaAccessGroup = OptionGroup('Access Control Options');

enum NPAOption<V> implements OptionDefinition<V> {
  configFile(
    FileOption(
      argName: 'config',
      envName: 'NPA_CONFIG',
      helpText: 'The path to a config file',
      fromDefault: defaultConfigFilePath<NPAParams>,
      mandatory: false,
      mode: PathExistMode.mayExist,
      group: SharedOptions.runtimeGroup,
    ),
  ),

  atsign(SharedOptions.atsign),
  keyfile(SharedOptions.keyfile),
  storagePath(SharedOptions.storagePath),
  passPhrase(SharedOptions.passPhrase),
  rootServer(SharedOptions.rootServer),

  eventLoggingAtsign(
    StringOption(
      argName: 'event-logging-atsign',
      configKey: '/events/logging-atsign',
      argAbbrev: 'l',
      mandatory: false,
      helpText: 'atSign of a noports logging service.',
      group: npaEventsGroup,
    ),
  ),

  daemonAtsigns(
    StringOption(
      argName: 'daemon-atsigns',
      configKey: '/access/daemon-atsigns',
      mandatory: false,
      defaultsTo: '',
      helpText: 'Comma-separated list of daemon atSigns which use this service',
      hide: true,
      group: npaAccessGroup,
    ),
  ),

  verbose(SharedOptions.verbose),
  debug(SharedOptions.debug),
  help(SharedOptions.help),
  version(SharedOptions.version);

  const NPAOption(this.option);

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

class NPAConfigBroker implements ConfigurationBroker {
  ({ConfigurationSource? config})? _cached;

  @override
  Object? valueOrNull(String key, Configuration<OptionDefinition> cfg) {
    if (_cached == null) {
      final file = cfg.value(NPAOption.configFile);
      _cached = (
        config: file.existsSync()
            ? ConfigurationParser.fromFile(file.path)
            : null,
      );
    }
    return _cached?.config?.valueOrNull(key);
  }
}
