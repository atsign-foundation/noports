import 'dart:io';

import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';

class NPAParams {
  final String policyAtsign;
  final String atKeysFilePath;
  final bool verbose;
  final String rootDomain;
  final String homeDirectory;
  final String? eventLoggingAtsign;
  final String? storagePath;
  final String policyVersion;
  final String allowList;
  final String persistenceMethod;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  NPAParams({
    required this.policyAtsign,
    required this.atKeysFilePath,
    required this.verbose,
    required this.rootDomain,
    required this.homeDirectory,
    required this.eventLoggingAtsign,
    required this.policyVersion,
    required this.allowList,
    required this.persistenceMethod,
    this.storagePath,
  });

  static Future<NPAParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String policyAtsign = (r['atsign'] as String).toAtsign();
    String homeDirectory = getHomeDirectory()!;

    return NPAParams(
      policyAtsign: policyAtsign,
      atKeysFilePath: r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, policyAtsign),
      verbose: r['verbose'],
      rootDomain: r['root-server'] ?? 'root.atsign.org',
      homeDirectory: homeDirectory,
      eventLoggingAtsign: r['event-logging-atsign'],
      policyVersion: r['policy-version'],
      storagePath: r['storage-path'],
      allowList: r['allow-list'] ?? policyAtsign,
      persistenceMethod: r['persistence-method'], // defaults to 'atserver'
    );
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    var parser = ArgParser(usageLineLength: usageLineLength);

    // Basic arguments
    parser.addFlag('help', negatable: false, help: 'Usage instructions');

    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this policy service',
    );

    parser.addOption(
      'event-logging-atsign',
      abbr: 'l',
      help: 'atSign of a noports logging service.',
    );

    // This is obsolete, thus is now hidden.
    // For closed networks, it is best to set an allow list on the policy
    // atSign's atServer using the `config` verb.
    parser.addOption(
      'daemon-atsigns',
      mandatory: false,
      defaultsTo: '',
      help: 'Comma-separated list of daemon atSigns which use this service',
      hide: true,
    );

    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'The atSign\'s atKeys file if not in ~/.atsign/keys/',
    );

    parser.addFlag('verbose', abbr: 'v', help: 'More logging');

    parser.addOption(
      'root-server',
      aliases: const ['root-domain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
      hide: true,
    );

    parser.addOption(
      'policy-version',
      mandatory: false,
      help: 'Version of policy to use. Defaults to "v1". '
        'Using v1 uses legacy policy rules. v2 includes more policy features',
      defaultsTo: 'v1',
      hide: false,
    );

    parser.addOption(
      'storage-path',
      abbr: 's',
      mandatory: false,
      help:
          'Path to atsign storage directory. Defaults to "~/.atsign/storage/<atSign>/sshnp/single/". '
          'Running multiple CLI atClient programs with the same storage path is not supported. '
          'An alternate storage directory can be passed through this argument when running multiple instances.',
    );

    parser.addOption(
      'allow-list',
      mandatory: false,
      help: 'This is a v2 feature. List of atSigns that can send policy data'
        ' operations (puts/gets) to the policy service API. E.g.'
        ' "@alice,@bob,@meow". Defaults to atSign specified by `-a` option'
        ' e.g. "@alice"'
    );

    parser.addOption(
      'persistence-method',
      mandatory: false,
      defaultsTo: 'atserver',
      help: 'This is a v2 feature.'
        ' Method to use for persistence of policy data. Options are:'
        ' "atserver" (default), "file" or "none". "atserver" uses the'
        ' atSign\'s'
        ' atServer for persistence of policy data. "file" uses local file'
        ' storage for policy data persistence. "none" means that policy data'
        ' will not be saved anywhere and will be lost when the service stops.',
    );

    return parser;
  }
}
