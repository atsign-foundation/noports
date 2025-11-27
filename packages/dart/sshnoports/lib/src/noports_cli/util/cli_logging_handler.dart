import 'dart:io';

import 'package:at_utils/at_logger.dart' show LoggingHandler;
import 'package:chalkdart/chalk.dart';
import 'package:logging/logging.dart' show Level, LogRecord;

/// A logging handler that outputs colored log messages to stderr for CLIs.
///
/// Formats log records with color-coded severity levels for better terminal readability.
class CLILoggingHandler implements LoggingHandler {
  /// Handles a log record by writing it to stderr with color formatting.
  ///
  /// Output format: [LEVEL] message
  @override
  void call(LogRecord record) {
    final String coloredLevel = _getColoredLevel(record.level);
    stderr.writeln('[${chalk.bold(coloredLevel)}] ${record.message}');
  }

  /// Returns a color-coded label for the given log level.
  String _getColoredLevel(Level level) {
    switch (level) {
      case Level.WARNING:
        return chalk.yellow('WARN');
      case Level.SEVERE:
      case Level.SHOUT:
        return chalk.red('ERROR');
      case Level.INFO:
        return chalk.blueBright('INFO');
      case Level.FINER:
      case Level.FINEST:
      default:
        return chalk.gray('FINER');
    }
  }
}
