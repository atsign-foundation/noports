
import 'dart:io';

// Usage example: runCommand('ls -l', runInShell: true);
Future<ProcessResult> runCommand(String command, {runInShell = false}) {
  final List<String> split = command.split(' ');
  final String exec = split.first;
  final List<String> args = split.sublist(1);
  return Process.run(exec, args, runInShell: runInShell);
}
