import 'dart:io';

// Usage example: runCommand('ls -l', runInShell: true);
Future<ProcessResult> runCommand(String command, {bool runInShell = false, String? workingDirectory}) async {
  final List<String> split = command.split(' ');
  final String exec = split.first;
  final List<String> args = split.sublist(1);
  final ProcessResult pres = await Process.run(exec, args, runInShell: runInShell, workingDirectory: workingDirectory);
  if(pres.exitCode != 0) {
    throw Exception('runCommand: $command | pres.exitCode: ${pres.exitCode}');
  }
  return pres;
}
