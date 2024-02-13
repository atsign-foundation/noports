import 'dart:async';

import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';

class StreamingLoggingHandler implements LoggingHandler {
  final LoggingHandler _wrappedLoggingHandler;
  final StreamController<String> _logSC = StreamController.broadcast();

  StreamingLoggingHandler(this._wrappedLoggingHandler);

  @override
  void call(LogRecord record) {
    _wrappedLoggingHandler.call(record);
    _logSC.add('${record.level.name}'
        '|${record.time}'
        '|${record.loggerName}'
        '|${record.message}');
  }

  Stream<String> get stream => _logSC.stream;
}
