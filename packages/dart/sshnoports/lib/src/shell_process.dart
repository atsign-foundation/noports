import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:noports_core/sshnp_foundation.dart';

class ChildProcessAsSshnpRemoteProcess implements SshnpRemoteProcess {
  final Process process;
  ChildProcessAsSshnpRemoteProcess(this.process);

  @override
  Future<void> get done => process.exitCode;

  @override
  Stream<List<int>> get stderr => process.stderr;

  @override
  StreamSink<List<int>> get stdin => process.stdin;

  @override
  Stream<List<int>> get stdout => process.stdout;
}

Future<void> runShellSession(SshnpRemoteProcess shell) async {
  shell.stdout.listen(stdout.add);
  shell.stderr.listen(stderr.add);

  // don't wait for a newline before sending to remote stdin
  stdin.lineMode = false;
  // echo only what is sent back from the other side
  stdin.echoMode = false;
  stdin.listen(shell.stdin.add);

  // catch local ctrl-c's and forward to remote
  ProcessSignal.sigint.watch().listen((signal) {
    shell.stdin.add(Uint8List.fromList([3]));
  });

  await shell.done;
}
