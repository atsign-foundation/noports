import 'dart:io';

import 'package:chalkdart/chalk.dart';

void displayBanner() {
  stderr.writeln('\n${chalk.bold('╔════════════════════════════════════╗')}');
  stderr.writeln(
    '${chalk.bold('║')}'
    '  ${chalk.cyan('Noports CLI')}'
    '                       ${chalk.bold('║')}',
  );
  stderr.writeln('${chalk.bold('╚════════════════════════════════════╝')}\n');
}

bool isHelpFlag(String arg) {
  const helpFlags = {'--help', '-h', 'help'};
  return helpFlags.contains(arg);
}

String? promptUser(String prompt) {
  stderr.write('$prompt: ');
  final input = stdin.readLineSync();

  if (input == null || input.trim().isEmpty) {
    stderr.writeln('No input provided; using default\n');
    return null;
  }

  return input.trim();
}
