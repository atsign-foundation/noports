import 'dart:io';

import 'package:noports_core/utils.dart';
import 'package:sshnoports/src/commands/at_activate.dart' as at_activate;
import 'package:sshnoports/src/commands/noports.dart' as noports;
import 'package:sshnoports/src/commands/np_admin.dart' as np_admin;
import 'package:sshnoports/src/commands/npevents.dart' as npevents;
import 'package:sshnoports/src/commands/npp.dart' as npp;
import 'package:sshnoports/src/commands/npp_atserver.dart' as npp_atserver;
import 'package:sshnoports/src/commands/npp_file.dart' as npp_file;
import 'package:sshnoports/src/commands/npt.dart' as npt;
import 'package:sshnoports/src/commands/srvd.dart' as srvd;
import 'package:sshnoports/src/commands/sshnp.dart' as sshnp;
import 'package:sshnoports/src/commands/sshnpd.dart' as sshnpd;
import 'package:sshnoports/src/print_version.dart';

const Map<String, Future<void> Function(List<String>)> _commands = {
  'at_activate': at_activate.main,
  'noports': noports.main,
  'np_admin': np_admin.main,
  'npevents': npevents.main,
  'npp': npp.main,
  'npp_atserver': npp_atserver.main,
  'npp_file': npp_file.main,
  'npt': npt.main,
  'srvd': srvd.main,
  'sshnp': sshnp.main,
  'sshnpd': sshnpd.main,
};

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && (args[0] == '--help' || args[0] == '-h')) {
    _printUsage(stdout);
    exit(0);
  }
  if (args.isNotEmpty && args[0] == '--version') {
    binaryName = 'atsc';
    printVersion();
    exit(0);
  }

  final command = args.isEmpty ? null : _commands[args[0]];
  if (command == null) {
    if (args.isNotEmpty) {
      stderr.writeln('Invalid command: ${args[0]}');
    }
    _printUsage(stderr);
    exit(1);
  }

  binaryName = args[0];
  // NOTE no exit here: a command may run on after its main returns.
  await command(args.sublist(1));
}

void _printUsage(IOSink sink) {
  sink
    ..writeln('Usage: atsc <command> [arguments]')
    ..writeln()
    ..writeln('NoPorts command-line programs: runs <command> with [arguments].')
    ..writeln('Each command is also installed under its own name: for example,')
    ..writeln('"npt <arguments>" does what "atsc npt <arguments>" does.')
    ..writeln()
    ..writeln('Commands:');
  for (final String name in _commands.keys) {
    sink.writeln('  $name');
  }
  sink
    ..writeln()
    ..writeln('Options:')
    ..writeln('  -h, --help     Print this usage')
    ..writeln('      --version  Print the version')
    ..writeln()
    ..writeln('Run "atsc <command> --help" for the options of a command.');
}
