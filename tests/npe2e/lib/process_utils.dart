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
  final Completer<void> _stdoutDone = Completer<void>();
  final Completer<void> _stderrDone = Completer<void>();

  // How long to keep waiting for stdout/stderr to close after the process has
  // exited. Normally the pipes close (and any buffered output is delivered)
  // immediately at exit; this is a safety net for the pathological case where
  // a child process inherited the pipes and holds them open.
  static const Duration _drainTimeout = Duration(seconds: 2);

  ProcessOutputCapture({
    required this.process,
    this.stdoutLogFile,
    this.stderrLogFile,
  }) {
    process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            stdoutBuffer.writeln(line);
            if (stdoutLogFile != null) {
              stdoutLogFile!.writeAsStringSync(
                '$line\n',
                mode: FileMode.append,
              );
            }
          },
          onDone: () {
            if (!_stdoutDone.isCompleted) _stdoutDone.complete();
          },
          onError: (Object _) {
            if (!_stdoutDone.isCompleted) _stdoutDone.complete();
          },
          cancelOnError: false,
        );

    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen(
          (line) {
            stderrBuffer.writeln(line);
            if (stderrLogFile != null) {
              stderrLogFile!.writeAsStringSync(
                '$line\n',
                mode: FileMode.append,
              );
            }
          },
          onDone: () {
            if (!_stderrDone.isCompleted) _stderrDone.complete();
          },
          onError: (Object _) {
            if (!_stderrDone.isCompleted) _stderrDone.complete();
          },
          cancelOnError: false,
        );
  }

  /// Completes with the process exit code AFTER stdout/stderr have been fully
  /// drained, so that [stdout] and [stderr] contain the process's complete
  /// output when this future resolves. (Process.exitCode on its own can
  /// complete before the last of the output has been delivered to the stream
  /// listeners, which makes assertions on [stdout] racy.)
  Future<int> get exitCode async {
    final int code = await process.exitCode;
    await Future.wait<void>([
      _stdoutDone.future,
      _stderrDone.future,
    ]).timeout(_drainTimeout, onTimeout: () => <void>[]);
    return code;
  }

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
    process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
      print('${executable} stdout: $data');
    });
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
      print('${executable} stderr: $data');
    });
  }
  if (stdoutLogFile != null) {
    process.stdout.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
      stdoutLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  if (stderrLogFile != null) {
    process.stderr.transform(const Utf8Decoder(allowMalformed: true)).listen((data) {
      stderrLogFile.writeAsStringSync(data, mode: FileMode.append);
    });
  }
  return process;
}
