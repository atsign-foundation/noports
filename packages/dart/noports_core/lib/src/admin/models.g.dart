// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

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

UserGroup _$UserGroupFromJson(Map<String, dynamic> json) => UserGroup(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      userAtSigns: (json['userAtSigns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      daemonAtSigns: (json['daemonAtSigns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      devices: (json['devices'] as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList(),
      deviceGroups: (json['deviceGroups'] as List<dynamic>)
          .map((e) => DeviceGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$UserGroupToJson(UserGroup instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'daemonAtSigns': instance.daemonAtSigns,
      'devices': instance.devices,
      'deviceGroups': instance.deviceGroups,
      'userAtSigns': instance.userAtSigns,
    };
