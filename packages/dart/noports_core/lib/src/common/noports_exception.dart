class SshnpException implements Exception {
  final Object message;
  final Object? error;
  final StackTrace? stackTrace;

  SshnpException(this.message, {this.error, this.stackTrace});

  @override
  String toString() {
    return message.toString();
  }

  String toVerboseString() {
    final sb = StringBuffer();
    sb.write(message);
    if (error != null) {
      sb.write('\n');
      sb.write('Error: $error');
    }
    if (stackTrace != null) {
      sb.write('\n');
      sb.write('Stack Trace: $stackTrace');
    }
    return sb.toString();
  }
}
