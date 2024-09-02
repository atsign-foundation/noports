import 'package:npt_flutter/app.dart';
import 'package:json_annotation/json_annotation.dart';

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
}

@JsonSerializable()
class Settings extends Loggable {
  final String relayAtsign;

  final bool overrideRelay;

  final PreferredViewLayout viewLayout;

  final bool darkMode;

  final Language language;

  const Settings({
    required this.relayAtsign,
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
      relayAtsign: relayAtsign ?? this.relayAtsign,
      overrideRelay: overrideRelay ?? this.overrideRelay,
      viewLayout: viewLayout ?? this.viewLayout,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }

  static const String customRelayKey = 'custom';

  Map<String, dynamic> toJson() => _$SettingsToJson(this);
  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

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
