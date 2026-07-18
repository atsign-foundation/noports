import 'dart:io';

import 'package:args/args.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:noports_core/src/srvd/build_env.dart';
import 'package:noports_core/src/srvd/relay_auth_verifiers.dart'
    show defaultRelayAuthDetectWindowMs;

class SrvdParams {
  final String atSign;
  final String homeDirectory;
  final String atKeysFilePath;
  final String passPhrase;
  final String managerAtsign;
  final String ipAddress;
  final bool verbose;
  final bool logTraffic;
  final String rootDomain;
  final bool perSessionStorage;
  final bool debug;

  /// Whether to start an isolate where all connections are to the same port
  final bool bind443;

  /// The actual port to bind to - for example in a docker env you may wish
  /// to forward port 443 on the host to some local port in the container
  final int localBindPort443;

  /// How long (ms) the auto-detecting relay auth verifiers wait for a
  /// connecting side to speak (legacy) before assuming ESCR and challenging it.
  final int relayAuthDetectWindowMs;

  // Non param variables
  static final ArgParser parser = _createArgParser();

  SrvdParams({
    required this.atSign,
    required this.homeDirectory,
    required this.atKeysFilePath,
    required this.passPhrase,
    required this.managerAtsign,
    required this.ipAddress,
    required this.verbose,
    required this.logTraffic,
    required this.rootDomain,
    required this.perSessionStorage,
    required this.bind443,
    required this.localBindPort443,
    required this.relayAuthDetectWindowMs,
    required this.debug,
  });

  static Future<SrvdParams> fromArgs(List<String> args) async {
    // Arg check
    ArgResults r = parser.parse(args);

    String atSign = r['atsign'];
    String homeDirectory;
    try {
      homeDirectory = getHomeDirectory(throwIfNull: true)!;
    } catch (e) {
      throw ArgumentError(e);
    }

    return SrvdParams(
      atSign: atSign,
      homeDirectory: homeDirectory,
      atKeysFilePath:
          r['key-file'] ?? getDefaultAtKeysFilePath(homeDirectory, atSign),
      passPhrase: r['pass-phrase'],
      managerAtsign: r['manager'],
      ipAddress: r['ip'],
      verbose: r['verbose'],
      logTraffic: BuildEnv.enableSnoop && r['snoop'],
      rootDomain: r['root-server'] ?? 'root.atsign.org',
      perSessionStorage: r['per-session-storage'],
      bind443: r['443'],
      localBindPort443: r['443-bind-port'] == null
          ? 443
          : int.parse(r['443-bind-port']),
      relayAuthDetectWindowMs: int.parse(r['relay-auth-detect-window-ms']),
      debug: r['debug'],
    );
  }

  static ArgParser _createArgParser() {
    var parser = ArgParser(
      usageLineLength: stdout.hasTerminal ? stdout.terminalColumns : null,
    );

    // Basic arguments
    parser.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help:
          'atSign\'s atKeys file if not in ~/.atsign/keys/'
          '  Alias: --keyFile',
    );
    parser.addOption(
      'pass-phrase',
      aliases: const ['passPhrase'],
      abbr: 'P',
      help: 'Pass Phrase to encrypt/decrypt the password protected atKeys file',
      mandatory: false,
      defaultsTo: '',
      hide: true,
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
      help: 'Show more logs (INFO and above)',
    );
    parser.addFlag(
      'debug',
      defaultsTo: false,
      help: 'Show all logs (FINEST and above)',
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
      'root-server',
      aliases: const ['root-domain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help:
          'atDirectory domain.'
          ' Alias (for backwards compatibility): --root-domain',
    );
    parser.addFlag(
      'per-session-storage',
      aliases: ['pss'],
      defaultsTo: true,
      negatable: true,
      help:
          'Use ephemeral local storage for each session.'
          ' When true, allows you to run multiple srvds concurrently on the'
          ' same host, as the same user. When false, only a single local srvd'
          ' may run concurrently on the same host as the same user.'
          ' Alias: --pss',
    );
    parser.addFlag(
      '443',
      defaultsTo: false,
      help:
          'Also bind to port 443, to support clients which want to connect'
          ' only to port 443 (for ... \$reasons)',
    );
    parser.addOption(
      '443-bind-port',
      mandatory: false,
      help:
          'The actual port to bind to - for example in a docker env you may'
          ' wish to forward port 443 on the host to a different port in the'
          ' container',
    );
    parser.addOption(
      'relay-auth-detect-window-ms',
      mandatory: false,
      defaultsTo: '$defaultRelayAuthDetectWindowMs',
      help:
          'How long (ms) to wait for a connecting side to send its legacy auth'
          ' before assuming it is using ESCR and issuing a challenge. Must'
          ' exceed a legacy peer\'s first-packet arrival (~one RTT after'
          ' connect); larger is safer for legacy peers, smaller speeds up ESCR'
          ' handshakes.',
    );
    parser.addFlag(
      'help',
      defaultsTo: false,
      negatable: false,
      help: 'Print usage',
    );
    parser.addFlag(
      'version',
      defaultsTo: false,
      negatable: false,
      help: 'Print version',
    );
    return parser;
  }
}
