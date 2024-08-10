// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Profile _$ProfileFromJson(Map<String, dynamic> json) => Profile(
      json['uuid'] as String,
      displayName: json['displayName'] as String,
      relayAtsign: json['relayAtsign'] as String,
      sshnpdAtsign: json['sshnpdAtsign'] as String,
      deviceName: json['deviceName'] as String,
      remoteHost: json['remoteHost'] as String? ?? 'localhost',
      remotePort: (json['remotePort'] as num).toInt(),
      localPort: (json['localPort'] as num).toInt(),
    );

Map<String, dynamic> _$ProfileToJson(Profile instance) => <String, dynamic>{
      'uuid': instance.uuid,
      'displayName': instance.displayName,
      'relayAtsign': instance.relayAtsign,
      'sshnpdAtsign': instance.sshnpdAtsign,
      'deviceName': instance.deviceName,
      'remoteHost': instance.remoteHost,
      'remotePort': instance.remotePort,
      'localPort': instance.localPort,
    };
