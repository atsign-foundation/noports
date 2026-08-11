import 'dart:io';

import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/config/file.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/events/events_params.dart';
import 'package:yaml/yaml.dart';

const OptionGroup eventsLoggingGroup = OptionGroup('Logging Options');

enum EventsOption<V> implements OptionDefinition<V> {
  configFile(
    FileOption(
      argName: 'config',
      envName: 'EVENTS_CONFIG',
      helpText: 'The path to a config file',
      fromDefault: defaultConfigFilePath<EventsParams>,
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

  loggingAtsigns(
    MultiStringOption(
      argName: 'logging-atsigns',
      configKey: '/logging/atsigns',
      argAbbrev: 'A',
      mandatory: true,
      helpText:
          'Comma-separated list of atSigns with whom to share logging config',
      group: eventsLoggingGroup,
    ),
  ),

  verbose(SharedOptions.verbose),
  debug(SharedOptions.debug),
  help(SharedOptions.help),
  version(SharedOptions.version);

  const EventsOption(this.option);

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

class EventsConfigBroker implements ConfigurationBroker {
  ({ConfigurationSource? config})? _cached;

  @override
  Object? valueOrNull(String key, Configuration<OptionDefinition> cfg) {
    if (_cached == null) {
      final file = cfg.value(EventsOption.configFile);
      _cached = (
        config: file.existsSync()
            ? ConfigurationParser.fromFile(file.path)
            : null,
      );
    }
    var value = _cached?.config?.valueOrNull(key);
    switch (key) {
      case '/logging/atsigns':
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
