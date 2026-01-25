import 'dart:io';

import 'package:noports_core/npp.dart';
import 'package:sshnoports/src/print_version.dart';
Future<void> main(List<String> args) async {
  // 1. Parse if --help was called
  try {
    if(NPPParams.argParser.parse(args)['help']) {
      print(NPPParams.argParser.usage);
      exit(0);
    }
    if(NPPParams.argParser.parse(args)['version']) {
      printVersion();
      exit(0);
    }
  } on ArgumentError catch (e) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } on FormatException catch (e) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(e.message);
    exit(1);
  } catch (err) {
    stderr.writeln('Usage: \n${NPPParams.argParser.usage}\n');
    stderr.writeln(err);
    exit(1);
  }

  final NPPParams nppParams;
}
