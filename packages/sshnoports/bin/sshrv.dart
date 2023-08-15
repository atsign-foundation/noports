import 'dart:io';

import 'package:sshnoports/sshrv/sshrv.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 2) {
    print('sshrv <host> <port>');
    exit(1);
  }

  String host = args[0];
  int streamingPort = int.parse(args[1]);

  await SSHRV.pureDart(host, streamingPort).run();
}
