import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/util/language.dart';

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
    required this.language,
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

enum RelayOptions {
  am,
  eu,
  ap,
}

extension RelayOptionsExtension on RelayOptions {
  String get relayAtsign {
    switch (this) {
      case RelayOptions.am:
        return '@rv_am';
      case RelayOptions.eu:
        return '@rv_eu';
      case RelayOptions.ap:
        return '@rv_ap';
    }
  }

  String get regions {
    final strings = AppLocalizations.of(App.navState.currentContext!)!;
    switch (this) {
      case RelayOptions.am:
        return strings.americas;
      case RelayOptions.eu:
        return strings.europe;
      case RelayOptions.ap:
        return strings.asiaPacific;
    }
  }
}



// ['English', 'Spanish', 'Br portuguese', 'Mandarin', 'Cantonese']