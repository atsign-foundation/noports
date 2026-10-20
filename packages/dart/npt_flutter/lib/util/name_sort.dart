/// Accented Latin letters and the letters they sort with.
const Map<String, String> _folds = <String, String>{
  'àáâãäåāăą': 'a',
  'çćĉċč': 'c',
  'ďđ': 'd',
  'èéêëēĕėęě': 'e',
  'ĝğġģ': 'g',
  'ĥħ': 'h',
  'ìíîïĩīĭįı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺļľŀł': 'l',
  'ñńņňŉ': 'n',
  'òóôõöøōŏő': 'o',
  'ŕŗř': 'r',
  'śŝşš': 's',
  'ţťŧ': 't',
  'ùúûüũūŭůűų': 'u',
  'ŵ': 'w',
  'ýÿŷ': 'y',
  'źżž': 'z',
  'æ': 'ae',
  'œ': 'oe',
  'ß': 'ss',
};

final Map<int, String> _foldByRune = <int, String>{
  for (final MapEntry<String, String> fold in _folds.entries)
    for (final int rune in fold.key.runes) rune: fold.value,
};

/// [name] lowercased and without accents, so that "Écran" sorts with the E's
/// rather than after Z.
String nameSortKey(String name) {
  final StringBuffer key = StringBuffer();
  for (final int rune in name.toLowerCase().runes) {
    final String? folded = _foldByRune[rune];
    if (folded != null) {
      key.write(folded);
    } else {
      key.writeCharCode(rune);
    }
  }
  return key.toString();
}
