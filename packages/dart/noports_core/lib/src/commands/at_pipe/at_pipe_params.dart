import 'dart:io';

import 'package:args/args.dart';
import 'package:at_commons/at_commons.dart' show AtRootDomain;
import 'package:at_commons/atsign.dart';
import 'package:noports_core/commands.dart';

class AtPipeParams {
  final Atsign atSign;
  final String pipeName;
  final bool isSender;
  final Atsign? toAtSign;
  final Set<Atsign> fromAtSigns;
  final Atsign relayAtSign;
  final AtRootDomain rootDomain;
  final String? atKeysFilePath;
  final bool verbose;
  final bool debug;

  static final ArgParser argParser = _createArgParser();

  AtPipeParams({
    required this.atSign,
    required this.pipeName,
    required this.isSender,
    this.toAtSign,
    required this.fromAtSigns,
    required this.relayAtSign,
    required this.rootDomain,
    this.atKeysFilePath,
    this.verbose = false,
    this.debug = false,
  });

  static AtPipeParams fromArgs(List<String> args) {
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    bool isSender;
    switch (args[0].toLowerCase()) {
      case 'send':
      case 's':
        isSender = true;
      case 'receive':
      case 'recv':
      case 'r':
        isSender = false;
      default:
        throw ArgumentError(
          'pipe command must be send (or s) or receive (or recv or r)',
        );
    }
    ArgResults r = argParser.parse(args);

    if (r.wasParsed('help')) {
      throw HelpRequestedException();
    }

    Atsign atSign = r['atsign'].toString().toAtsign();
    return AtPipeParams(
      atSign: atSign,
      pipeName: r['pipe-name'],
      isSender: isSender,
      toAtSign: r['to-atsign']?.toString().toAtsign(),
      fromAtSigns: <Atsign>{}
        ..addAll(
          (r['from-atsigns'].toString())
              .split(',')
              .map((s) => s.isEmpty ? atSign : s.trim().toAtsign()),
        ),
      relayAtSign: r['relay-atsign'].toString().toAtsign(),
      rootDomain: AtRootDomain.parse(r['root-server']),
      atKeysFilePath: r['key-file'],
      verbose: r['verbose'],
      debug: r['debug'],
    );
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    ArgParser p = ArgParser(usageLineLength: usageLineLength);

    p.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'The atSign of this pipe sender or receiver',
    );

    p.addOption('pipe-name', abbr: 'p', mandatory: true, help: 'The pipe name');

    p.addOption(
      'to-atsign',
      abbr: 't',
      mandatory: false,
      help:
          'For senders: the atSign being sent to.'
          ' Defaults to being the same as the "--atsign" parameter',
    );

    p.addOption(
      'from-atsigns',
      abbr: 'f',
      mandatory: false,
      defaultsTo: '',
      help:
          'For receivers: comma separated list of the allowed sender atSigns'
          ' - e.g. "@alice,@bob".'
          ' Defaults to being the same as the "--atsign" parameter',
    );

    p.addOption(
      'relay-atsign',
      abbr: 'r',
      mandatory: false,
      defaultsTo: '@rv_eu',
      help: 'Relay atSign',
    );

    p.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      help: 'The atSign\'s atKeys file if not in ~/.atsign/keys/',
    );

    p.addOption(
      'root-server',
      abbr: 'R',
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help:
          'atDirectory (aka root) server domain. e.g.root.atsign.org,'
          ' root.atsign.org:64, proxy:proxy0001.atsign.org:443',
    );

    p.addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this usage info',
    );

    p.addFlag(
      'verbose',
      abbr: 'v',
      negatable: false,
      help: 'More logging (INFO and above)',
    );

    p.addFlag('debug', negatable: false, help: 'All the logging');

    return p;
  }
}
