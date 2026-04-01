import 'dart:io';

import 'package:args/args.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/config/file.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/npp/npp_params.dart';
import 'package:yaml/yaml.dart';

const OptionGroup nppNamespaceGroup = OptionGroup('Namespace Options');
const OptionGroup nppAccessGroup = OptionGroup('Access Control Options');
const OptionGroup nppPolicyGroup = OptionGroup('Policy Options');

enum NPPOption<V> implements OptionDefinition<V> {
  configFile(
    FileOption(
      argName: 'config',
      envName: 'NPP_CONFIG',
      helpText: 'The path to a config file',
      fromDefault: defaultConfigFilePath<NPPParams>,
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

  baseNamespace(
    StringOption(
      argName: 'base-namespace',
      configKey: '/namespace/base',
      argAliases: ['namespace'],
      mandatory: false,
      defaultsTo: 'sshnp',
      helpText: 'Application namespace',
      group: nppNamespaceGroup,
    ),
  ),

  domainNamespace(
    StringOption(
      argName: 'domain-namespace',
      configKey: '/namespace/domain',
      mandatory: false,
      defaultsTo: 'npp',
      helpText: 'Domain namespace',
      group: nppNamespaceGroup,
    ),
  ),

  persistenceMethod(
    StringOption(
      argName: 'persistence-method',
      configKey: '/policy/persistence-method',
      mandatory: false,
      defaultsTo: 'atserver',
      helpText:
          'Define the persistence of the policy data. Method to use for '
          'persistence of policy data. Options are: "atserver" (default), '
          '"file" or "none". "atserver" uses the atSign\'s atServer for '
          'persistence of policy data. "file" uses local file storage for '
          'policy data persistence. "none" means that policy data will not '
          'be saved anywhere and will be lost when the service stops.',
      group: nppPolicyGroup,
    ),
  ),

  managerAllowList(
    MultiStringOption(
      argName: 'manager-allow-list',
      configKey: '/access/manager-allow-list',
      mandatory: false,
      helpText:
          'List of atSigns that can manage policy data and send RPCs to the '
          'Policy Manager API. atSigns in this list can send policy '
          'operations (puts/gets) to the policy service API. E.g. '
          '"@alice,@bob,@meow". Defaults to the atSign specified by `-a`. '
          'Set it to empty string ("") to disable any atSigns from editing '
          'policy rules.',
      group: nppAccessGroup,
    ),
  ),

  eventLoggingAtsign(
    StringOption(
      argName: 'event-logging-atsign',
      configKey: '/events/logging-atsign',
      mandatory: false,
      helpText: 'atSign of a noports logging service.',
      group: nppPolicyGroup,
    ),
  ),

  policyDirectory(
    DirOption(
      argName: 'policy-directory',
      configKey: '/policy/directory',
      mandatory: false,
      helpText:
          'This option only applies when using --persistence-method="file". '
          'Path to npp storage directory where policy rules are stored in '
          'file format.',
      group: nppPolicyGroup,
    ),
  ),

  verbose(SharedOptions.verbose),
  debug(SharedOptions.debug),
  help(SharedOptions.help),
  version(SharedOptions.version);

  const NPPOption(this.option);

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

class NPPConfigBroker implements ConfigurationBroker {
  ({ConfigurationSource? config})? _cached;

  @override
  Object? valueOrNull(String key, Configuration<OptionDefinition> cfg) {
    if (_cached == null) {
      final file = cfg.value(NPPOption.configFile);
      _cached = (
        config: file.existsSync()
            ? ConfigurationParser.fromFile(file.path)
            : null,
      );
    }
    var value = _cached?.config?.valueOrNull(key);
    switch (key) {
      case '/access/manager-allow-list':
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
