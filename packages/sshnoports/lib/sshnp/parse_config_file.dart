import 'dart:io';

import 'package:sshnoports/sshnp/sshnp_arg.dart';

List<String> parseConfigFile(String fileName) {
  List<String> args = <String>[];

  File file = File(fileName);
  List<String> lines = file.readAsLinesSync();

  for (String line in lines) {
    if (line.startsWith('#')) continue;

    var parts = line.split('=');
    if (parts.length != 2) continue;

    var key = parts[0].trim();
    var value = parts[1].trim();

    SSHNPArg arg = SSHNPArg.fromBashName(key);
    if (arg.name.isEmpty) continue;

    switch (arg.format) {
      case ArgFormat.flag:
        if (value.toLowerCase() == 'true') {
          args.add('--${arg.name}');
        }
        continue;
      case ArgFormat.multiOption:
        var values = value.split(';');
        for (String val in values) {
          if (val.isEmpty) continue;
          args.add('--${arg.name}');
          args.add(val);
        }
        continue;
      case ArgFormat.option:
        if (value.isEmpty) continue;
        args.add('--${arg.name}');
        args.add(value);
        continue;
    }
  }
  return args;
}
