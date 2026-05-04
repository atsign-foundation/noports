enum Language { dart, c }

Language languageFromString(final String language) {
  switch (language) {
    case 'dart':
    case 'd':
      return Language.dart;
    case 'c':
      return Language.c;
    default:
      throw Exception('Unsupported language: $language');
  }
}
