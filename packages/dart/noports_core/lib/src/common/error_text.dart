/// The text a log gives for [error]: its own text in full, except for a
/// [FormatException], whose source (the input that failed to parse) is left
/// out in favour of its type, message and offset.
String errorForLog(Object error) {
  if (error is! FormatException) return '$error';
  final message = error.message.isEmpty ? '' : ': ${error.message}';
  final offset = error.offset == null ? '' : ' (at offset ${error.offset})';
  return '${error.runtimeType}$message$offset';
}
