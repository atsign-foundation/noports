import 'dart:io';

import 'package:at_onboarding_cli/src/cli/auth_cli.dart' as auth_cli;

Future<void> main(List<String> args) async {
  try {
    exit(await auth_cli.main(args));
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
