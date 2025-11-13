import 'dart:io';

import 'package:chalkdart/chalk.dart';

void writeError(String message) {
  stderr.write(chalk.bold(chalk.brightRed('[ERROR] ')));
  stderr.writeln(message);
}

void writeInfoMessage(String message) {
  stdout.write(chalk.bold(chalk.blueBright('[INFO] ')));
  stdout.writeln(message);
}

void writeWarning(String message) {
  stdout.write(chalk.bold(chalk.yellow('[WARN] ')));
  stdout.writeln(message);
}

void writeSuccessMessage(String message) {
  stdout.write(chalk.bold(chalk.greenBright('[SUCCESS] ')));
  stdout.writeln(message);
}

void displayBanner() {
  print('\n${chalk.bold('╔════════════════════════════════════╗')}');
  print(
    '${chalk.bold('║')}  ${chalk.cyan('Noports CLI')}                  ${chalk.bold('║')}',
  );
  print('${chalk.bold('╚════════════════════════════════════╝')}\n');
}
