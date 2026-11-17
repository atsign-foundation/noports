import 'dart:io';

/// Stops a daemon on a signal: the first signal stops it and then exits with
/// 0, and a signal while that stop runs, or before there is a daemon to stop,
/// exits with 1 at once.
class SignalStopper {
  SignalStopper({required this.exit, required this.log});

  /// Ends the program with an exit code.
  final void Function(int exitCode) exit;

  /// Reports what a signal did.
  final void Function(String message) log;

  /// Stops the daemon; null until there is a daemon to stop.
  Future<void> Function()? stop;

  bool _stopping = false;

  /// Handles one [signal].
  Future<void> handle(ProcessSignal signal) async {
    final Future<void> Function()? stopNow = stop;
    if (_stopping || stopNow == null) {
      exit(1);
      return;
    }
    _stopping = true;
    log('$signal received, stopping');
    try {
      await stopNow();
    } catch (e) {
      log('error while stopping: $e');
    }
    exit(0);
  }
}
