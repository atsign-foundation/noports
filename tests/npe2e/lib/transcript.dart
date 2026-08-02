import 'dart:io';

/// The test harness's own narration: what the harness is doing, and why it
/// decided a test passed or failed.
///
/// This is deliberately a third thing alongside the two capture primitives that
/// already exist: `LogFragment` is a time slice of a container's log, and
/// `ProcessOutputCapture` is one child process's stdout/stderr. Neither of them
/// records the harness's own reasoning, which is what you actually need first
/// when reading a failed run.
///
/// Every line is written twice:
///
/// - to stdout, coloured, for whoever is watching the run;
/// - to `file`, plain text, because CI archives only the on-disk logs directory
///   (`.github/workflows/e2e_all.yaml` zips `$LOGS_DIR`). Anything that is only
///   `print`ed is lost once the workflow log ages out.
///
/// Every line carries [tag], a short identity for whatever emitted it, so that
/// output from concurrently running tests stays attributable and greppable.
class Transcript {
  // Same raw-ANSI vocabulary as lib/print_test_utils.dart, plus orange for
  // warnings to match tests/e2e_all/scripts/common/common_functions.include.sh.
  static const String _reset = '\x1B[0m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _orange = '\x1B[33m';
  static const String _blue = '\x1B[34m';

  /// Short identity of the emitter, e.g. a policy test's device name.
  final String tag;

  /// Plain-text (never coloured) copy of every line. Null disables persistence.
  final File? file;

  Transcript({required this.tag, this.file});

  /// A transcript writing to the same [file] under a different [tag].
  Transcript withTag(final String tag) => Transcript(tag: tag, file: file);

  void section(final String title) => _write('====', title, colour: _blue);

  void info(final String message) => _write('INFO', message);

  void ok(final String message) => _write('OK', message, colour: _green);

  void warn(final String message) => _write('WARN', message, colour: _orange);

  void error(
    final String message, [
    final Object? error,
    final StackTrace? stackTrace,
  ]) {
    _write('ERROR', message, colour: _red);
    if (error != null) {
      _write('ERROR', error.toString(), colour: _red);
    }
    if (stackTrace != null) {
      _write('ERROR', stackTrace.toString(), colour: _red);
    }
  }

  /// Records a command line so a failing step can be reproduced by hand. The
  /// policy suite passes `printCommand: false` everywhere to keep the untagged
  /// `> ...` lines from interleaving unreadably; this is the tagged replacement.
  void command(final String executable, final List<String> arguments) {
    _write('INFO', '> $executable ${arguments.join(' ')}');
  }

  /// Splits [message] so that a multi-line value (a stack trace, a captured log)
  /// still gets one tag per line and stays greppable.
  void _write(
    final String level,
    final String message, {
    final String? colour,
  }) {
    final String prefix = '${_timestamp()} ${level.padRight(5)} [$tag]';
    final StringBuffer plain = StringBuffer();
    for (final String line in message.split('\n')) {
      plain.writeln('$prefix $line');
      if (colour == null) {
        print('$prefix $line');
      } else {
        print('$colour$prefix$_reset $line');
      }
    }
    file?.writeAsStringSync(plain.toString(), mode: FileMode.append);
  }

  static String _timestamp() {
    final DateTime now = DateTime.now();
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    final String second = now.second.toString().padLeft(2, '0');
    final String millisecond = now.millisecond.toString().padLeft(3, '0');
    return '$hour:$minute:$second.$millisecond';
  }
}
