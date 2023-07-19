import 'dart:io';
import 'package:sshnoports/sshrvd/sshrvd.dart';

void main(List<String> args) async {
  SSHRVD? sshrvd;

  try {
    sshrvd = await SSHRVD.fromCommandLineArgs(args);
    await sshrvd.init();
    await sshrvd.run();
  } on ArgumentError catch (_) {
    exit(1);
  } catch (error, stackTrace) {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
