import 'dart:io';

import 'package:sshnoports/sshrv/sshrv.dart';

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    print('sshrv <host> <port> [localhost sshd port, defaults to 22]');
    exit(-1);
  }

  String host = args[0];
  int streamingPort = int.parse(args[1]);

  int localSshdPort = 22;

  if (args.length > 2) {
    localSshdPort = int.parse(args[2]);
  }

  await SSHRV.pureDart(host, streamingPort, localSshdPort: localSshdPort).run();
}
