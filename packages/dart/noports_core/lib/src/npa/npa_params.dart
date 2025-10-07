import 'dart:io';

import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';

class NPAParams {
  final String policyAtsign;
  final Set<String> daemonAtsigns;
  final String atKeysFilePath;
  final bool verbose;
  final String rootDomain;
  final String homeDirectory;
  final String eventLoggingAtsign;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  NPAParams({
    required this.policyAtsign,
    required this.daemonAtsigns,
    required this.atKeysFilePath,
    required this.verbose,
    required this.rootDomain,
    required this.homeDirectory,
    required this.eventLoggingAtsign,
  });

  static Future<NPAParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String policyAtsign = (r['atsign'] as String).toAtsign();
    String homeDirectory = getHomeDirectory()!;

    return NPAParams(
      policyAtsign: policyAtsign,
      daemonAtsigns: r['daemon-atsigns'].toString().split(',').toSet(),
      atKeysFilePath:
          r['key-file'] ??
          getDefaultAtKeysFilePath(homeDirectory, policyAtsign),
      verbose: r['verbose'],
      rootDomain: r['root-server'] ?? 'root.atsign.org',
      homeDirectory: homeDirectory,
      eventLoggingAtsign: r['logging-atsign'] ?? policyAtsign,
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
      'logging-atsign',
      abbr: 'l',
      help:
          'atSign of a noports logging service. Defaults to'
          ' being the same as this policy service\'s atSign',
    );

    // This is basically obsolete, thus is now hidden.
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

    return parser;
  }
}
