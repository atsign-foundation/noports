import 'dart:io';
import 'package:sshnoports/sshrvd/sshrvd.dart';

void main(List<String> args) async {
  SSHRVD sshrvd = await SSHRVD.fromCommandLineArgs(args);

  try {
    await sshrvd.init();
    await sshrvd.run();
  } catch (error, stackTrace) {
    stderr.writeln('sshrvd: ${error.toString()}');
    stderr.writeln('stack trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
