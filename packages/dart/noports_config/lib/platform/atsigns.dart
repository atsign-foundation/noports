import 'package:at_commons/at_commons.dart'
    show AtsignString, InvalidAtSignException;

/// Lenient atsign helpers over at_commons' `toAtsign()`, which is what
/// sshnpd itself applies: lower-cased, given its "@", dots dropped
/// (@colin.constable is @colinconstable), at most 55 code points, and
/// refused for reserved characters, white space or control characters.
///
/// `toAtsign()` throws on partial input such as a bare "@", which is
/// exactly what a text field holds while the user is typing, so UI code
/// goes through these and never calls it directly.
class Atsigns {
  Atsigns._();

  static bool isValid(String? s) => s != null && problem(s) == null;

  /// Why [s] is not an atsign, in at_commons' words, or null when it is.
  static String? problem(String? s) {
    if (s == null || s.trim().isEmpty) return 'An atsign is required.';
    try {
      s.trim().toAtsign();
      return null;
    } on InvalidAtSignException catch (e) {
      return e.message;
    }
  }

  /// The canonical "@name" for anything that is an atsign, otherwise null.
  static String? normalize(String? s) {
    if (s == null) return null;
    final t = s.trim();
    if (t.isEmpty) return null;
    try {
      return t.toAtsign();
    } on InvalidAtSignException {
      return null;
    }
  }

  /// The text with any leading "@" signs removed, for a field that shows
  /// the "@" itself. Spaces are dropped too since an atsign has none.
  static String bare(String s) =>
      s.replaceAll(RegExp(r'^\s*@+'), '').replaceAll(RegExp(r'\s'), '');

  /// What to store for text typed into an atsign field: the canonical
  /// form when the text is an atsign, otherwise "@" plus the text as typed
  /// (lower-cased), so validation can name the problem rather than the
  /// field silently dropping characters. Null when nothing was typed.
  static String? fromInput(String s) {
    final b = bare(s);
    if (b.isEmpty) return null;
    return normalize(b) ?? '@${b.toLowerCase()}';
  }
}
