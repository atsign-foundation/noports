import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_core/commands.dart';

class IssueKeysParams {
  final String atsign;
  final String? atKeysFilePath;
  final String? passPhrase;
  final String rootDomain;

  String? device;
  String? otp;

  // Logging
  bool verbose = false;
  bool debug = false;

  static final ArgParser argParser = _createArgParser();

  IssueKeysParams({
    required this.atsign,
    this.device,
    this.otp,
    this.atKeysFilePath,
    this.passPhrase,
    required this.rootDomain,
    this.verbose = false,
    this.debug = false,
  });

  static IssueKeysParams fromArgs(List<String> args) {
    ArgResults r = argParser.parse(args);

    if (r.wasParsed('help')) {
      throw HelpRequestedException();
    }

    return IssueKeysParams(
      atsign: r['atsign'],
      device: r['device'],
      atKeysFilePath: r['key-file'],
      passPhrase: r['pass-phrase'],
      rootDomain: r['root-server'],
      verbose: r['verbose'],
      debug: r['debug'],
    );
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    ArgParser p = ArgParser(usageLineLength: usageLineLength);
    p.addOption('atsign', abbr: 'a', mandatory: true, help: 'The atSign');

    p.addOption(
      'key-file',
      abbr: 'k',
      mandatory: false,
      aliases: const ['keyFile'],
      help: 'The atSign\'s atKeys file if not in ~/.atsign/keys/',
    );

    p.addOption(
      'pass-phrase',
      abbr: 'P',
      mandatory: false,
      help: 'Pass phrase to decrypt the password protected atKeys file',
    );

    p.addOption(
      'device',
      abbr: 'd',
      mandatory: false,
      help: 'Name for the device being activated',
    );

    p.addOption(
      'root-server',
      abbr: 'r',
      aliases: const ['root-domain', 'rootDomain'],
      mandatory: false,
      defaultsTo: 'root.atsign.org',
      help: 'atDirectory (aka root) server domain (e.g., root.atsign.org)',
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

    p.addFlag(
      'debug',
      negatable: false,
      help: 'More logging (DEBUG and above)',
    );

    return p;
  }
}
