// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtEventConfig _$AtEventConfigFromJson(Map<String, dynamic> json) =>
    AtEventConfig(
      atSign: json['atSign'] as String,
      topic: json['topic'] as String,
      ttln: (json['ttln'] as num).toInt(),
    );

Map<String, dynamic> _$AtEventConfigToJson(AtEventConfig instance) =>
    <String, dynamic>{
      'atSign': instance.atSign,
      'topic': instance.topic,
      'ttln': instance.ttln,
    };
