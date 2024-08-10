import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';

part 'settings.g.dart';

// Tried to give these more descriptive names based on what is going into them
// so if we add more they will kind of make sense
@JsonEnum(fieldRename: FieldRename.kebab)
enum PreferredViewLayout {
  minimal, // simple
  sshStyle, // advanced
}

@JsonEnum()
enum Language {
  @JsonValue("en")
  english,
}

@JsonSerializable()
class Settings extends Equatable {
  final String defaultRelayAtsign;
  final String? customRelayAtsign;

  final bool overrideRelay;

  final PreferredViewLayout viewLayout;

  final bool darkMode;

  final Language language;

  const Settings({
    required this.defaultRelayAtsign,
    this.customRelayAtsign,
    required this.overrideRelay,
    required this.viewLayout,
    this.darkMode = false,
    this.language = Language.english,
  });

  Settings copyWith({
    String? defaultRelayAtsign,
    String? customRelayAtsign,
    bool? overrideRelay,
    PreferredViewLayout? viewLayout,
    bool? darkMode,
    Language? language,
  }) {
    return Settings(
      defaultRelayAtsign: defaultRelayAtsign ?? this.defaultRelayAtsign,
      customRelayAtsign: customRelayAtsign ?? this.customRelayAtsign,
      overrideRelay: overrideRelay ?? this.overrideRelay,
      viewLayout: viewLayout ?? this.viewLayout,
      darkMode: darkMode ?? this.darkMode,
      language: language ?? this.language,
    );
  }

  String get relayAtsign => defaultRelayAtsign == 'custom'
      ? customRelayAtsign ?? defaultRelayAtsign
      : defaultRelayAtsign;

  Map<String, dynamic> toJson() => _$SettingsToJson(this);
  factory Settings.fromJson(Map<String, dynamic> json) =>
      _$SettingsFromJson(json);

  @override
  List<Object?> get props => [
        defaultRelayAtsign,
        customRelayAtsign,
        overrideRelay,
        viewLayout,
        darkMode,
        language,
      ];
}
