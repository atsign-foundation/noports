// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
      defaultRelayAtsign: json['defaultRelayAtsign'] as String,
      customRelayAtsign: json['customRelayAtsign'] as String?,
      overrideRelay: json['overrideRelay'] as bool,
      viewLayout: $enumDecode(_$PreferredViewLayoutEnumMap, json['viewLayout']),
      darkMode: json['darkMode'] as bool? ?? false,
      language: $enumDecodeNullable(_$LanguageEnumMap, json['language']) ??
          Language.english,
    );

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
      'defaultRelayAtsign': instance.defaultRelayAtsign,
      'customRelayAtsign': instance.customRelayAtsign,
      'overrideRelay': instance.overrideRelay,
      'viewLayout': _$PreferredViewLayoutEnumMap[instance.viewLayout]!,
      'darkMode': instance.darkMode,
      'language': _$LanguageEnumMap[instance.language]!,
    };

const _$PreferredViewLayoutEnumMap = {
  PreferredViewLayout.minimal: 'minimal',
  PreferredViewLayout.sshStyle: 'ssh-style',
};

const _$LanguageEnumMap = {
  Language.english: 'en',
};
