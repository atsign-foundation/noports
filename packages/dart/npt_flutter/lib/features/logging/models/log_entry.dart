import 'package:npt_flutter/features/logging/logging.dart';

final class LogEntry extends Loggable {
  final EquatableDateTime timestamp;
  final Loggable loggable;

  LogEntry(this.loggable, {DateTime? timestamp})
      : timestamp = EquatableDateTime.fromDateTime(timestamp ?? DateTime.now());

  @override
  List<Object?> get props => [timestamp, loggable];

  @override
  String toString() {
    return '$timestamp | $loggable';
  }
}
