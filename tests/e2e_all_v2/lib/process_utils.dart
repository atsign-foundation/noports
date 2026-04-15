import 'dart:io';

Future<ProcessResult> runCommand(
  final String executable,
  final List<String> arguments, {
  final String? workingDirectory,
  final Map<String, String>? environment,
  final bool printCommand = true,
  final bool printOutput = false,
}) async {
  if(printCommand) {
    print('> $executable ${arguments.join(' ')}');
  }
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printOutput) {
    print('stdout:\n\t${result.stdout}');
    print('stderr:\n\t${result.stderr}');
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
}) async {
  if(printOutput) {
    print('> $executable ${arguments.join(' ')}');
  }
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printOutput) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stdout: $data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stderr: $data');
    });
  }
  return process;
}
