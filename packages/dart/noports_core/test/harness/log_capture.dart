import 'dart:async';

import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Collects log records instead of printing them.
class LogCapture implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);

  /// The records from the logger named [loggerName].
  List<LogRecord> from(String loggerName) =>
      records.where((r) => r.loggerName == loggerName).toList();

  /// Waits up to [timeout] for a record matching [test], failing with [what]
  /// if none comes.
  Future<void> waitFor(
    String what,
    bool Function(LogRecord) test, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (!records.any(test)) {
      if (DateTime.now().isAfter(deadline)) {
        fail('Nothing logged $what within ${timeout.inSeconds}s');
      }
      await Future.delayed(const Duration(milliseconds: 20));
    }
    await pumpEventQueue();
  }

  /// A [LogCapture] which is the default handler of every logger the test
  /// file constructs, emptied before each test. One serves the whole file,
  /// since some components bind the default handler once per isolate.
  static LogCapture install() {
    final capture = LogCapture();
    late LoggingHandler previous;
    setUpAll(() {
      previous = AtSignLogger.defaultLoggingHandler;
      AtSignLogger.defaultLoggingHandler = capture;
    });
    tearDownAll(() => AtSignLogger.defaultLoggingHandler = previous);
    setUp(capture.records.clear);
    return capture;
  }
}

/// The text of each of [records] holding any of [needles].
List<String> recordsHolding(
  Iterable<LogRecord> records,
  Iterable<String> needles,
) => [
  for (final record in records)
    for (final text in [record.message, '${record.error ?? ''}'])
      if (needles.any(text.contains)) '${record.loggerName}: $text',
];

/// The text of each of [records] holding either half of [key], which finds
/// the key whether it was logged as it is, JSON-encoded or cut short.
List<String> recordsHoldingKey(Iterable<LogRecord> records, String key) {
  final half = key.length ~/ 2;
  return recordsHolding(records, [key.substring(0, half), key.substring(half)]);
}
