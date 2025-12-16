import 'dart:io';

import 'package:args/args.dart';
import 'package:noports_core/commands.dart';

class IssueKeysParams {
  final String atsign;
  final String? atKeysFilePath;
  final String? passPhrase;
  String? device;

  // for internal use
  String? otp;

  static final ArgParser argParser = _createArgParser();

  IssueKeysParams({
    required this.atsign,
    this.device,
    this.atKeysFilePath,
    this.passPhrase,
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
    );
  }

  static ArgParser _createArgParser() {
    int? usageLineLength = stdout.hasTerminal ? stdout.terminalColumns : null;
    ArgParser p = ArgParser(usageLineLength: usageLineLength);

    p.addFlag('help', abbr: 'h', negatable: false, help: 'Usage instructions');

    p.addOption(
      'atsign',
      abbr: 'a',
      mandatory: true,
      help: 'atSign of this policy service',
    );

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
      help: 'Pass phrase to encrypt/decrypt the password protected atKeys file',
    );

    p.addOption(
      'device',
      abbr: 'd',
      mandatory: false,
      help: 'Name of the device this enrollment is created for',
    );

    p.addFlag('verbose', abbr: 'v', negatable: false, help: 'More logging');

    return p;
  }
}
