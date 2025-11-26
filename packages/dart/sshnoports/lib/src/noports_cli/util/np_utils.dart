import 'package:chalkdart/chalk.dart';

void displayBanner() {
  print('\n${chalk.bold('╔════════════════════════════════════╗')}');
  print(
    '${chalk.bold('║')}  ${chalk.cyan('Noports CLI')}                  ${chalk.bold('║')}',
  );
  print('${chalk.bold('╚════════════════════════════════════╝')}\n');
}