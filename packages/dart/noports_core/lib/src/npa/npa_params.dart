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

  // Non param variables
  static final ArgParser parser = _createArgParser();

  NPAParams({
    required this.policyAtsign,
    required this.atKeysFilePath,
    required this.verbose,
    required this.rootDomain,
    required this.homeDirectory,
    required this.eventLoggingAtsign,
    this.storagePath,
  });

  static Future<NPAParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String policyAtsign = (r['atsign'] as String).toAtsign();
    String homeDirectory = getHomeDirectory()!;

    return NPAParams(
      policyAtsign: policyAtsign,
      atKeysFilePath:
          r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, policyAtsign),
      verbose: r['verbose'],
      rootDomain: r['root-server'] ?? 'root.atsign.org',
      homeDirectory: homeDirectory,
      eventLoggingAtsign: r['event-logging-atsign'],
      storagePath: r['storage-path'],
    );
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    var parser = ArgParser(usageLineLength: usageLineLength);

    // Basic arguments
    parser.addFlag('help', negatable: false, help: 'Usage instructions');

    parser.addFlag('version', negatable: false, help: 'Print version');

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
      'storage-path',
      abbr: 's',
      mandatory: false,
      help:
          'Path to atsign storage directory. Defaults to "~/.atsign/storage/<atSign>/sshnp/single/". '
          'Running multiple CLI atClient programs with the same storage path is not supported. '
          'An alternate storage directory can be passed through this argument when running multiple instances.',
    );

    return parser;
  }
}
