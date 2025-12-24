// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
  json['uuid'] as String? ?? '',
  displayName: json['displayName'] as String,
  relayAtsign: json['relayAtsign'] as String?,
  sshnpdAtsign: json['sshnpdAtsign'] as String,
  deviceName: json['deviceName'] as String,
  remoteHost: json['remoteHost'] as String? ?? StringConst.localhost,
  remotePort: (json['remotePort'] as num).toInt(),
  localPort: (json['localPort'] as num).toInt(),
  localHost: json['localHost'] as String? ?? 'localhost',
  only443: json['only443'] as bool? ?? false,
  keepAlive: json['keepAlive'] as bool? ?? false,
  connectUri: json['connectUri'] as String?,
);

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
  'displayName': instance.displayName,
  'relayAtsign': instance.relayAtsign,
  'sshnpdAtsign': instance.sshnpdAtsign,
  'deviceName': instance.deviceName,
  'remoteHost': instance.remoteHost,
  'remotePort': instance.remotePort,
  'localPort': instance.localPort,
  'localHost': instance.localHost,
  'only443': instance.only443,
  'keepAlive': instance.keepAlive,
  'connectUri': instance.connectUri,
};
