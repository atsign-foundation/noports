
part of 'policy.dart';


DaemonAtSign _$DaemonAtSignFromJson(Map<String, dynamic> json) => DaemonAtSign(
      atSign: json['atSign'] as String,
    );

Map<String, dynamic> _$DaemonAtSignToJson(DaemonAtSign instance) =>
    <String, dynamic>{
      'atSign': instance.atSign,
    };

UserAtSign _$UserAtSignFromJson(Map<String, dynamic> json) => UserAtSign(
      atSign: json['atSign'] as String,
    );

Map<String, dynamic> _$UserAtSignToJson(UserAtSign instance) =>
    <String, dynamic>{
      'atSign': instance.atSign,
    };

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

Role _$RoleFromJson(Map<String, dynamic> json) => Role(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String,
      daemonAtSigns: (json['daemonAtSigns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      devices: (json['devices'] as List<dynamic>)
          .map((e) => Device.fromJson(e as Map<String, dynamic>))
          .toList(),
      deviceGroups: (json['deviceGroups'] as List<dynamic>)
          .map((e) => DeviceGroup.fromJson(e as Map<String, dynamic>))
          .toList(),
      userAtSigns: (json['userAtSigns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$RoleToJson(Role instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'daemonAtSigns': instance.daemonAtSigns,
      'devices': instance.devices,
      'deviceGroups': instance.deviceGroups,
      'userAtSigns': instance.userAtSigns,
    };
