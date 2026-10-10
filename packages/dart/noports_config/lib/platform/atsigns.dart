/// Lenient atSign helpers. at_utils' `fixAtSign` throws on partial input
/// such as a bare "@", which is exactly what a text field holds while the
/// user is typing, so UI code must never call it directly.
class Atsigns {
  Atsigns._();

  static final _valid = RegExp(r'^@?[a-zA-Z0-9_]{1,55}$');

  static bool isValid(String? s) => s != null && _valid.hasMatch(s.trim());

  /// "@name" for anything that looks like an atSign, otherwise null.
  static String? normalize(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (!_valid.hasMatch(t)) return null;
    return t.startsWith('@') ? t.toLowerCase() : '@${t.toLowerCase()}';
  }
}
