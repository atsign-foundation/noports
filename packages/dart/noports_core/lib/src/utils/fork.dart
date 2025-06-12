import 'dart:io' show Process, Platform, ProcessStartMode;

Future<Process> fork(
  List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool includeParentEnvironment = true,
  bool runInShell = false,
  ProcessStartMode mode = ProcessStartMode.normal,
}) {
  String executable;
  var path = Platform.script.toFilePath(windows: Platform.isWindows);
  if (path.endsWith(".dart")) {
    // dart run
    executable = "dart";
    arguments.insert(0, path);
    arguments.insert(0, "run");
  } else if (path.endsWith(".aot")) {
    // aot compiled
    executable = "dartaotruntime";
    arguments.insert(0, path);
  } else {
    // raw binary
    executable = path;
  }

  return Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    includeParentEnvironment: includeParentEnvironment,
    runInShell: runInShell,
    mode: mode,
  );
}
