import 'dart:io';

import 'package:at_client_cli/at_client_cli.dart' show AtActivate;

Future<void> main(List<String> args) async {
  try {
    exit(await AtActivate.main(args));
  } catch (e) {
    stdout.writeln(e.toString());
    exit(1);
  }
}
