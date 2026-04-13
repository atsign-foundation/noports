import 'dart:io';

Future<ProcessResult> runCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  printCommand = false,
  dynamic stdinData,
}) async {
  print('> $executable ${arguments.join(' ')}');
  final ProcessResult result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printCommand) {
    print('stdout:\n\t${result.stdout}');
    print('stderr:\n\t${result.stderr}');
  }
  return result;
}

Future<Process> startCommand(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool printCommand = false,
}) async {
  print('> $executable ${arguments.join(' ')}');
  final Process process = await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  if(printCommand) {
    process.stdout.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stdout: $data');
    });
    process.stderr.transform(SystemEncoding().decoder).listen((data) {
      print('${executable} stderr: $data');
    });
  }
  return process;
}
