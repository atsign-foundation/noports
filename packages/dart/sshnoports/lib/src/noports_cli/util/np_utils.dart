import 'dart:io';

import 'package:chalkdart/chalk.dart';

void displayBanner() {
  print('\n${chalk.bold('╔════════════════════════════════════╗')}');
  print(
    '${chalk.bold('║')}  ${chalk.cyan('Noports CLI')}                  ${chalk.bold('║')}',
  );
  print('${chalk.bold('╚════════════════════════════════════╝')}\n');
}

bool hasHelpFlag(List<String> args) {
  const helpFlags = {'--help', '-h', 'help'};
  return args.any((value) => helpFlags.contains(value));
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
