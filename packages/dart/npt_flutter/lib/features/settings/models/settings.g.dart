// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Settings _$SettingsFromJson(Map<String, dynamic> json) => Settings(
  relayAtsign: json['relayAtsign'] as Atsign,
  overrideRelay: json['overrideRelay'] as bool,
  viewLayout: $enumDecode(_$PreferredViewLayoutEnumMap, json['viewLayout']),
  darkMode: json['darkMode'] as bool? ?? false,
  language: $enumDecode(_$LanguageEnumMap, json['language']),
  sortMode:
      $enumDecodeNullable(
        _$ProfileSortModeEnumMap,
        json['sortMode'],
        unknownValue: ProfileSortMode.manual,
      ) ??
      ProfileSortMode.manual,
  favoritesFirst: json['favoritesFirst'] as bool? ?? false,
);

Map<String, dynamic> _$SettingsToJson(Settings instance) => <String, dynamic>{
  'relayAtsign': instance.relayAtsign,
  'overrideRelay': instance.overrideRelay,
  'viewLayout': _$PreferredViewLayoutEnumMap[instance.viewLayout]!,
  'darkMode': instance.darkMode,
  'language': _$LanguageEnumMap[instance.language]!,
  'sortMode': _$ProfileSortModeEnumMap[instance.sortMode]!,
  'favoritesFirst': instance.favoritesFirst,
};

const _$PreferredViewLayoutEnumMap = {
  PreferredViewLayout.minimal: 'minimal',
  PreferredViewLayout.sshStyle: 'ssh-style',
};

const _$LanguageEnumMap = {
  Language.english: 'en',
  Language.spanish: 'es',
  Language.portuguese: 'pt-br',
  Language.mandarin: 'zh-hans-cn',
  Language.cantonese: 'zh-hant-hk',
};

const _$ProfileSortModeEnumMap = {
  ProfileSortMode.manual: 'manual',
  ProfileSortMode.nameAscending: 'name-ascending',
  ProfileSortMode.nameDescending: 'name-descending',
};
