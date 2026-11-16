/// Lenient atsign helpers. at_utils' `fixAtSign` throws on partial input
/// such as a bare "@", which is exactly what a text field holds while the
/// user is typing, so UI code must never call it directly.
class Atsigns {
  Atsigns._();

  static final _valid = RegExp(r'^@?[a-zA-Z0-9_]{1,55}$');

  static bool isValid(String? s) => s != null && _valid.hasMatch(s.trim());

  /// "@name" for anything that looks like an atsign, otherwise null.
  static String? normalize(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (!_valid.hasMatch(t)) return null;
    return t.startsWith('@') ? t.toLowerCase() : '@${t.toLowerCase()}';
  }

  /// The text with any leading "@" signs removed, for a field that shows
  /// the "@" itself. Spaces are dropped too since an atsign has none.
  static String bare(String s) =>
      s.replaceAll(RegExp(r'^\s*@+'), '').replaceAll(RegExp(r'\s'), '');

  /// What to store for text typed into an atsign field: "@" plus the
  /// typed name, lowercased, or null when nothing was typed. Never throws
  /// and never drops characters, so validation can still point at a typo.
  static String? fromInput(String s) {
    final b = bare(s).toLowerCase();
    return b.isEmpty ? null : '@$b';
  }
}
