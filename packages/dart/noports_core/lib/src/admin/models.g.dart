// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
      timestamp: (json['timestamp'] as num).toInt(),
      deviceAtsign: json['deviceAtsign'] as String,
      policyAtsign: json['policyAtsign'] as String?,
      devicename: json['devicename'] as String,
      deviceGroupName: json['deviceGroupName'] as String,
      version: json['version'] as String,
      corePackageVersion: json['corePackageVersion'] as String,
      supportedFeatures: json['supportedFeatures'] as Map<String, dynamic>,
      allowedServices: (json['allowedServices'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      status: json['status'] as String?,
    );

Map<String, dynamic> _$DeviceInfoToJson(DeviceInfo instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'deviceAtsign': instance.deviceAtsign,
      'policyAtsign': instance.policyAtsign,
      'devicename': instance.devicename,
      'deviceGroupName': instance.deviceGroupName,
      'version': instance.version,
      'corePackageVersion': instance.corePackageVersion,
      'supportedFeatures': instance.supportedFeatures,
      'allowedServices': instance.allowedServices,
      'status': instance.status,
    };

PolicyLogEvent _$PolicyLogEventFromJson(Map<String, dynamic> json) =>
    PolicyLogEvent(
      timestamp: (json['timestamp'] as num).toInt(),
      deviceAtsign: json['deviceAtsign'] as String,
      policyAtsign: json['policyAtsign'] as String?,
      devicename: json['devicename'] as String,
      deviceGroupName: json['deviceGroupName'] as String,
      clientAtsign: json['clientAtsign'] as String,
      authorized: json['authorized'] as bool,
      message: json['message'] as String?,
      permitOpen: (json['permitOpen'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );

Map<String, dynamic> _$PolicyLogEventToJson(PolicyLogEvent instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'deviceAtsign': instance.deviceAtsign,
      'policyAtsign': instance.policyAtsign,
      'devicename': instance.devicename,
      'deviceGroupName': instance.deviceGroupName,
      'clientAtsign': instance.clientAtsign,
      'authorized': instance.authorized,
      'message': instance.message,
      'permitOpen': instance.permitOpen,
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
