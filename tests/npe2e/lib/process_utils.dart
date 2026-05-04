import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:npe2e/print_test_utils.dart' as print_utils;

class ProcessOutputCapture {
  final Process process;
  final StringBuffer stdoutBuffer = StringBuffer();
  final StringBuffer stderrBuffer = StringBuffer();
  final File? stdoutLogFile;
  final File? stderrLogFile;

  ProcessOutputCapture({
    required this.process,
    this.stdoutLogFile,
    this.stderrLogFile,
  }) {
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stdoutBuffer.writeln(line);
          if (stdoutLogFile != null) {
            stdoutLogFile!.writeAsStringSync('$line\n', mode: FileMode.append);
          }
        });

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          stderrBuffer.writeln(line);
          if (stderrLogFile != null) {
            stderrLogFile!.writeAsStringSync('$line\n', mode: FileMode.append);
          }
        });
  }

  Future<int> get exitCode => process.exitCode;

  String get stdout => stdoutBuffer.toString();
  String get stderr => stderrBuffer.toString();
}

Future<ProcessOutputCapture> startCommandWithCapture(
  final String executable,
  final List<String> arguments, {
  required final File stdoutLogFile,
  required final File stderrLogFile,
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
}) async {
  final Process process = await startCommand(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    printCommand: printCommand,
  );
  return ProcessOutputCapture(
    process: process,
    stdoutLogFile: stdoutLogFile,
    stderrLogFile: stderrLogFile,
  );
}

Future<ProcessResult> runCommand(
  final String executable,
  final List<String> arguments, {
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
  final bool printOutput = false,
  final File? stdoutLogFile,
  final File? stderrLogFile,
}) async {
  if (printCommand) {
    print_utils.printCommand(executable, arguments);
  }
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if (printOutput) {
    print('stdout:\n\t${result.stdout}');
    print('stderr:\n\t${result.stderr}');
  }
  if (stdoutLogFile != null) {
    await stdoutLogFile.writeAsString(result.stdout.toString());
  }
  if (stderrLogFile != null) {
    await stderrLogFile.writeAsString(result.stderr.toString());
  }
  return result;
}

Future<Process> startCommand(
  final String executable,
  final List<String> arguments, {
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
  final bool printOutput = false,
  final File? stdoutLogFile,
  final File? stderrLogFile,
}) async {
  if (printCommand) {
    print_utils.printCommand(executable, arguments);
  }
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if (printOutput) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stdout: $data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stderr: $data');
    });
  }
  if (stdoutLogFile != null) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      stdoutLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  if (stderrLogFile != null) {
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      stderrLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  return process;
}
