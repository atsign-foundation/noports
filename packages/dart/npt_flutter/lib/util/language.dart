import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

@JsonEnum()
enum Language {
  @JsonValue("en")
  english,
  @JsonValue("es")
  spanish,
  @JsonValue("pt-br")
  portuguese,
}

extension LanguageExtension on Language {
  Locale get locale {
    switch (this) {
      case Language.english:
        return const Locale('en');
      case Language.spanish:
        return const Locale('es');
      case Language.portuguese:
        return const Locale('pt', 'BR');
    }
  }

  String get displayName {
    switch (this) {
      case Language.english:
        return 'English';
      case Language.spanish:
        return 'Español';
      case Language.portuguese:
        return 'Português';
    }
  }
}

class LanguageUtil {
  // Static method to get the Language enum from a Locale.
  // Returns English if the language code is not supported.
  static Language getLanguageFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return Language.english;
      case 'es':
        return Language.spanish;
      case 'pt':
        return Language.portuguese;
      default:
        return Language.english;
    }
  }
}
