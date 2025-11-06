import 'dart:io';

import 'package:at_commons/at_commons.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:chalkdart/chalk.dart';
import 'package:noports_activate/input_method_test.dart';
import 'package:noports_activate/src/activate/noports_activate_utils.dart';
import 'activate/np_activate_impl.dart';

final NPActivate noportsAuth = NPActivateImpl();

Future<void> main(List<String> args) async {
  _displayBanner();
  if (args.isEmpty) {
    throw IllegalArgumentException('No arguments found');
  }

  String program = args[0];
  switch(program){
    case 'activate':
      await wrappedActivateMain(args);
      break;
    case 'issue-keys':
      await wrappedIssueKeysMain(args);
      break;
    default:
      throw IllegalArgumentException('Unknown argument: \'$program\'');
  }
}


Future<void> wrappedIssueKeysMain(List<String> args) async {}




void _displayBanner() {
  print('\n${chalk.bold('╔════════════════════════════════════╗')}');
  print(
    '${chalk.bold('║')}  ${chalk.cyan(
        'Noports')}                  ${chalk.bold('║')}',
  );
  print('${chalk.bold('╚════════════════════════════════════╝')}\n');
}