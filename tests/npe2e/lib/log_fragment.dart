import 'dart:io';

class LogFragment {
  final File stdoutFile;
  final File stderrFile;
  final Future<Process> Function() processStarter;

  Process? _process;

  LogFragment({
    required this.stdoutFile,
    required this.stderrFile,
    required this.processStarter,
  });

  Future<void> start() async {
    await stdoutFile.create(recursive: true);
    await stderrFile.create(recursive: true);
    _process = await processStarter();
  }

  Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      await _process!.exitCode;
    }
  }
}
