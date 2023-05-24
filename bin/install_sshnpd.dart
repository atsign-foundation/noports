import 'dart:io';

import 'package:args/args.dart';
import 'package:sshnoports/version.dart';

/// This binary is not meant to be ran here.
/// It is meant to be ran in the same directory as the other binaries: `sshnp`, `sshnpd`, `sshrvd`, `sshrv`, `.startup.sh`, etc.
/// The arguments are the same as `sshnpd` as it will initialize a `.startup.sh` script with the arguments for starting the daemon.

// Usage: "./install_sshnpd --help"
void main(List<String> arguments) async {
  try {
    await _main(arguments);
  } catch (error, stackTrace) {
    stderr.writeln('sshnpd: ${error.toString()}');
    stderr.writeln('stack trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}

Future<void> _main(List<String> arguments) async {
  final ArgParser parser = ArgParser();
  parser.addOption('keyFile', abbr: 'k', mandatory: false, help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/');
  parser.addOption('atsign', abbr: 'a', mandatory: true, help: 'atSign of this device');
  parser.addOption('manager',
      abbr: 'm', mandatory: true, help: 'Managers atSign, that this device will accept triggers from');
  parser.addOption('device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help: 'Send a trigger to this device, allows multiple devices share an atSign');

  parser.addFlag('sshpublickey', abbr: 's', help: 'Update authorized_keys to include public key from sshnp');
  parser.addFlag('username',
      abbr: 'u', help: 'Send username to the manager to allow sshnp to display username in command line');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  try {
    final ArgResults argResults = parser.parse(arguments);

  } catch (e) {
    (e);
    version();
    stdout.writeln(parser.usage);
    exit(0);
  }
}

