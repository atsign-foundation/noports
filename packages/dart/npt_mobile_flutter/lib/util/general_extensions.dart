extension StringExtension on String {
  String atsignify() {
    var value = trim();
    if (!startsWith('@')) {
      value = '@$this';
    }

    return value;
  }
}
