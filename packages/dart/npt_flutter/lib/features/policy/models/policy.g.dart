// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'policy.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Device _$DeviceFromJson(Map<String, dynamic> json) => Device(
  name: json['name'] as String,
  permitOpens: (json['permitOpens'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$DeviceToJson(Device instance) => <String, dynamic>{
  'name': instance.name,
  'permitOpens': instance.permitOpens,
};

DeviceGroup _$DeviceGroupFromJson(Map<String, dynamic> json) => DeviceGroup(
  name: json['name'] as String,
  permitOpens: (json['permitOpens'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
);

Map<String, dynamic> _$DeviceGroupToJson(DeviceGroup instance) =>
    <String, dynamic>{
      'name': instance.name,
      'permitOpens': instance.permitOpens,
    };

FetchedRole _$FetchedRoleFromJson(Map<String, dynamic> json) => FetchedRole(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String,
  daemonAtsigns: (json['daemonAtSigns'] as List<dynamic>)
      .map((e) => const AtsignConverter().fromJson(e as String))
      .toList(),
  devices: (json['devices'] as List<dynamic>)
      .map((e) => Device.fromJson(e as Map<String, dynamic>))
      .toList(),
  deviceGroups: (json['deviceGroups'] as List<dynamic>)
      .map((e) => DeviceGroup.fromJson(e as Map<String, dynamic>))
      .toList(),
  userAtsigns: (json['userAtSigns'] as List<dynamic>)
      .map((e) => const AtsignConverter().fromJson(e as String))
      .toList(),
)..tempId = json['tempId'] as String?;

Map<String, dynamic> _$FetchedRoleToJson(FetchedRole instance) =>
    <String, dynamic>{
      'tempId': instance.tempId,
      'name': instance.name,
      'description': instance.description,
      'daemonAtSigns': instance.daemonAtsigns
          .map(const AtsignConverter().toJson)
          .toList(),
      'devices': instance.devices,
      'deviceGroups': instance.deviceGroups,
      'userAtSigns': instance.userAtsigns
          .map(const AtsignConverter().toJson)
          .toList(),
      'id': instance.id,
    };
