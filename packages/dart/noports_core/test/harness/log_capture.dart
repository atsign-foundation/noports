import 'dart:async';

import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

/// Collects log records instead of printing them.
class LogCapture implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);

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

  /// Waits until [quiet] goes by with no new record, which says nothing of
  /// whether a handler has finished, and fails if that takes over [timeout].
  Future<void> untilQuiet({
    Duration quiet = const Duration(seconds: 1),
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    var seen = records.length;
    var since = DateTime.now();
    while (DateTime.now().difference(since) < quiet) {
      if (DateTime.now().isAfter(deadline)) {
        fail(
          'The log did not go quiet for ${quiet.inMilliseconds}ms within'
          ' ${timeout.inSeconds}s',
        );
      }
      await Future.delayed(const Duration(milliseconds: 20));
      if (records.length != seen) {
        seen = records.length;
        since = DateTime.now();
      }
    }
  }

  /// A [LogCapture] which is the default handler of every logger the test
  /// file constructs, each logging at every level unless it sets its own,
  /// emptied before each test. One serves the whole file, since some
  /// components bind the default handler once per isolate.
  static LogCapture install() {
    final capture = LogCapture();
    late LoggingHandler previousHandler;
    late String previousLevel;
    setUpAll(() {
      previousHandler = AtSignLogger.defaultLoggingHandler;
      previousLevel = AtSignLogger.root_level;
      AtSignLogger.defaultLoggingHandler = capture;
      AtSignLogger.root_level = 'all';
    });
    tearDownAll(() {
      AtSignLogger.defaultLoggingHandler = previousHandler;
      AtSignLogger.root_level = previousLevel;
    });
    setUp(capture.records.clear);
    return capture;
  }
}

/// The messages of those of [records] that the logger named [loggerName]
/// wrote.
List<String> messagesFrom(Iterable<LogRecord> records, String loggerName) => [
  for (final record in records)
    if (record.loggerName == loggerName) record.message,
];

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
