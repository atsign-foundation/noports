import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:npt_flutter/app.dart';

part 'settings.g.dart';

// Tried to give these more descriptive names based on what is going into them
// so if we add more they will kind of make sense
@JsonEnum(fieldRename: FieldRename.kebab)
enum PreferredViewLayout {
  minimal("Simple"),
  sshStyle("Advanced");

  const PreferredViewLayout(this.displayName);
  final String displayName;
}

@JsonEnum()
enum Language {
  @JsonValue("en")
  english,
  @JsonValue("es")
  spanish,
  @JsonValue("pt-br")
  portuguese,
}

@JsonSerializable()
class Settings extends Loggable {
  final String relayAtsign;

  final bool overrideRelay;

  final PreferredViewLayout viewLayout;

  final bool darkMode;

  final Language language;

  const Settings({
    this.relayAtsign = '@rv_am',
    required this.overrideRelay,
    required this.viewLayout,
    this.darkMode = false,
    this.language = Language.english,
  });

  Settings copyWith({
    String? relayAtsign,
    bool? overrideRelay,
    PreferredViewLayout? viewLayout,
    bool? darkMode,
    Language? language,
  }) {
    return Settings(
      relayAtsign: (relayAtsign == null || relayAtsign.isEmpty) ? '@rv_am' : relayAtsign,
      overrideRelay: overrideRelay ?? this.overrideRelay,
      viewLayout: viewLayout ?? this.viewLayout,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }

  static const String customRelayKey = 'custom';

  Map<String, dynamic> toJson() => _$SettingsToJson(this);
  factory Settings.fromJson(Map<String, dynamic> json) => _$SettingsFromJson(json);

  @override
  List<Object?> get props => [
        relayAtsign,
        overrideRelay,
        viewLayout,
        darkMode,
        language,
      ];

  @override
  String toString() {
    return 'Settings with relay:$relayAtsign, '
        'overrideRelay: $overrideRelay, view: $viewLayout, '
        'darkMode: $darkMode, lang: ${_$LanguageEnumMap[language]}';
  }
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

// ['English', 'Spanish', 'Br portuguese', 'Mandarin', 'Cantonese']