import 'package:equatable/equatable.dart';
import 'package:npt_flutter/features/logging/logging.dart';

class EquatableDateTime extends DateTime
    with EquatableMixin
    implements Loggable {
  EquatableDateTime(
    super.year, [
    super.month,
    super.day,
    super.hour,
    super.minute,
    super.second,
    super.millisecond,
    super.microsecond,
  ]);

  EquatableDateTime.fromDateTime(DateTime dateTime)
      : super(
          dateTime.year,
          dateTime.month,
          dateTime.day,
          dateTime.hour,
          dateTime.minute,
          dateTime.second,
          dateTime.millisecond,
          dateTime.microsecond,
        );

  @override
  List<Object> get props {
    return [year, month, day, hour, minute, second, millisecond, microsecond];
  }

  @override
  String toString() {
    return toUtc().toIso8601String();
  }
}
