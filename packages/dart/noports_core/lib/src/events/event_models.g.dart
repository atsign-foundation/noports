// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AtEventLoggingConfig _$AtEventLoggingConfigFromJson(
  Map<String, dynamic> json,
) => AtEventLoggingConfig(
  atSign: json['atSign'] as String,
  topic: json['topic'] as String,
  ttln: (json['ttln'] as num).toInt(),
);

Map<String, dynamic> _$AtEventLoggingConfigToJson(
  AtEventLoggingConfig instance,
) => <String, dynamic>{
  'atSign': instance.atSign,
  'topic': instance.topic,
  'ttln': instance.ttln,
};
