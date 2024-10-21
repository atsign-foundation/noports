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
  @JsonValue("cn")
  mandarin,
  @JsonValue("hk")
  cantonese,
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
      case Language.cantonese:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'HK');
      case Language.mandarin:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'CN');
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
      case Language.cantonese:
        return '廣東話';
      case Language.mandarin:
        return '普通话';
    }
  }
}

class LanguageUtil {
  // Static method to get the Language enum from a Locale.
  // Returns English if the language code is not supported.
  static Language getLanguageFromLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'pt_BR':
        return Language.portuguese;
      case 'zh_Hans_CH':
        return Language.mandarin;
      case 'zh_Hant_HK':
        return Language.cantonese;
      default:
        if (locale.languageCode.startsWith('zh_Hans')) {
          return Language.mandarin;
        } else if (locale.languageCode.startsWith('zh_Hant')) {
          return Language.cantonese;
        } else if (locale.languageCode.startsWith('pt')) {
          return Language.portuguese;
        } else if (locale.languageCode.startsWith('es')) {
          return Language.spanish;
        } else {
          return Language.english;
        }
    }
  }
}
