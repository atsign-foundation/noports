import 'dart:io';

import 'package:noports_core/srv.dart';

/// Reads its own path as atsc's entry point does, prints "ready", then on
/// SIGUSR1 prints the srv it would run.
Future<void> main() async {
  Platform.resolvedExecutable;
  final Future<ProcessSignal> signal = ProcessSignal.sigusr1.watch().first;
  stdout.writeln('ready');
  await signal;
  stdout.writeln(await Srv.getLocalBinaryPath());
}
