import 'dart:io';

import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:noports_core/src/srvd/build_env.dart';

class SrvdParams {
  final String username;
  final String atSign;
  final String homeDirectory;
  final String atKeysFilePath;
  final String managerAtsign;
  final String ipAddress;
  final bool verbose;
  final bool logTraffic;
  final String rootDomain;
  final bool perSessionStorage;
  final bool bind443;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SrvdParams({
    required this.username,
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.managerAtsign,
    required this.ipAddress,
    required this.verbose,
    required this.logTraffic,
    required this.rootDomain,
    required this.perSessionStorage,
    required this.bind443,
  });

  static Future<SrvdParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String atSign = r['atsign'];
    String homeDirectory = getHomeDirectory()!;

    return SrvdParams(
      username: getUserName(throwIfNull: true)!,
      atSign: atSign,
      homeDirectory: homeDirectory,
      atKeysFilePath:
          r['key-file'] ?? getDefaultAtKeysFilePath(homeDirectory, atSign),
      managerAtsign: r['manager'],
      ipAddress: r['ip'],
      verbose: r['verbose'],
      logTraffic: BuildEnv.enableSnoop && r['snoop'],
      rootDomain: r['root-domain'],
      perSessionStorage: r['per-session-storage'],
      bind443: r['443'],
    );
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser(
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
      showAliasesInUsage: true,
    );

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'atSign\'s atKeys file if not in ~/.atsign/keys/',
    );
    parser.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign for srvd',
    );
    parser.addOption(
      'manager',
      abbr: 'm',
      defaultsTo: 'open',
      mandatory: false,
      help:
          'Managers atSign that srvd will accept requests from. Default is any atSign can use srvd',
    );
    parser.addOption(
      'ip',
      abbr: 'i',
      mandatory: true,
      help: 'FQDN/IP address sent to clients',
    );
    parser.addFlag(
      'verbose',
      abbr: 'v',
      help: 'More logging',
    );
    if (BuildEnv.enableSnoop) {
      parser.addFlag(
        'snoop',
        abbr: 's',
        defaultsTo: false,
        help: 'Log traffic passing through service',
      );
    }
    parser.addOption(
      'root-domain',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory domain',
    );
    parser.addFlag(
      'per-session-storage',
      aliases: ['pss'],
      defaultsTo: true,
      negatable: true,
      help: 'Use ephemeral local storage for each session.'
          ' When true, allows you to run multiple srvds concurrently on the'
          ' same host, as the same user. When false, only a single local srvd'
          ' may run concurrently on the same host as the same user.',
    );
    parser.addFlag(
      '443',
      defaultsTo: false,
      help: 'Also bind to port 443, to support clients which want to connect'
          ' only to port 443 (for ... \$reasons)',
    );
    parser.addFlag(
      'help',
      defaultsTo: false,
      negatable: false,
      help: 'Print usage',
    );
    return parser;
  }
}
