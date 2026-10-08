String prettyDuration(Duration duration) {
  if (duration.isNegative || duration == Duration.zero) {
    return '0 seconds';
  }

  final int hours = duration.inHours;
  final int minutes = duration.inMinutes.remainder(60);
  final int seconds = duration.inSeconds.remainder(60);
  final List<String> parts = <String>[];

  if (hours > 0) {
    parts.add('$hours hour${hours == 1 ? '' : 's'}');
  }
  if (minutes > 0) {
    parts.add('$minutes minute${minutes == 1 ? '' : 's'}');
  }
  if (seconds > 0 || parts.isEmpty) {
    parts.add('$seconds second${seconds == 1 ? '' : 's'}');
  }

  return parts.join(' ');
}
