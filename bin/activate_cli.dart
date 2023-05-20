import 'dart:io';

import 'package:at_onboarding_cli/src/activate_cli/activate_cli.dart'
    as activate_cli;

Future<void> main(List<String> args) async {
  try {
    await activate_cli.main(args);
  } catch (e) {
    print(e.toString());
  }
  exit(0);
}
