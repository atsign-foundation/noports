import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// An extension of [Equatable] which forces implementors to override [toString]
/// Hence the name Loggable - which is used by this apps logging system.
/// This ensures that every State or Event in the system will provided well
/// thought out log messages.
abstract class Loggable extends Equatable {
  const Loggable();
  @override
  @mustBeOverridden
  String toString();
}

class LoggableString extends Loggable {
  final String string;
  const LoggableString(this.string);

  @override
  List<Object?> get props => [string];

  @override
  String toString() {
    return string;
  }
}

extension LoggableStringExtension on String {
  Loggable get loggable => LoggableString(this);
}

// ignore: missing_override_of_must_be_overridden
class LoggableObject extends LoggableString {
  const LoggableObject(super.string);
}

extension LoggableObjectExtension on Object {
  Loggable get loggable => LoggableObject(toString());
}
