import 'dart:io';
import 'package:sshnoports/sshnpd/sshnpd.dart';

void main(List<String> args) async {
  SSHNPD sshnpd = await SSHNPD.fromCommandLineArgs(args);

  try {
    await sshnpd.init();

    await sshnpd.run();
  } catch (error, stackTrace) {
    stderr.writeln('sshnpd: ${error.toString()}');
    stderr.writeln('stack trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
