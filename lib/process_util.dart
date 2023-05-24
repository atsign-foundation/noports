import 'dart:io';

// Usage example: runCommand('ls -l', runInShell: true);
Future<ProcessResult> runCommand(String command, {bool runInShell = false, String? workingDirectory}) {
  final List<String> split = command.split(' ');
  final String exec = split.first;
  final List<String> args = split.sublist(1);
  return Process.run(exec, args, runInShell: runInShell, workingDirectory: workingDirectory);
}
