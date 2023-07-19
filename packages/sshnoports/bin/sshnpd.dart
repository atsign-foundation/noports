import 'dart:io';
import 'package:sshnoports/sshnpd/sshnpd.dart';

void main(List<String> args) async {
  SSHNPD? sshnpd;

  try {
    sshnpd = await SSHNPD.fromCommandLineArgs(args);

    await sshnpd.init();
    await sshnpd.run();
  } on ArgumentError catch (_) {
    exit(1);
  } catch (error, stackTrace) {
    stderr.writeln('Error: ${error.toString()}');
    stderr.writeln('Stack Trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}
