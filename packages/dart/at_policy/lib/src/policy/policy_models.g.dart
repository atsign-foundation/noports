// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'policy_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PolicyIntent _$PolicyIntentFromJson(Map<String, dynamic> json) => PolicyIntent(
      intent: json['intent'] as String,
      params: json['params'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$PolicyIntentToJson(PolicyIntent instance) =>
    <String, dynamic>{
      'intent': instance.intent,
      'params': instance.params,
    };

PolicyInfo _$PolicyInfoFromJson(Map<String, dynamic> json) => PolicyInfo(
      intent: json['intent'] as String,
      info: json['info'] as Map<String, dynamic>,
    );

Map<String, dynamic> _$PolicyInfoToJson(PolicyInfo instance) =>
    <String, dynamic>{
      'intent': instance.intent,
      'info': instance.info,
    };

PolicyRequest _$PolicyRequestFromJson(Map<String, dynamic> json) =>
    PolicyRequest(
      daemonAtsign: json['daemonAtsign'] as String,
      daemonDeviceName: json['daemonDeviceName'] as String,
      daemonDeviceGroupName: json['daemonDeviceGroupName'] as String,
      clientAtsign: json['clientAtsign'] as String,
      intents: (json['intents'] as List<dynamic>)
          .map((e) => PolicyIntent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PolicyRequestToJson(PolicyRequest instance) =>
    <String, dynamic>{
      'daemonAtsign': instance.daemonAtsign,
      'daemonDeviceName': instance.daemonDeviceName,
      'daemonDeviceGroupName': instance.daemonDeviceGroupName,
      'clientAtsign': instance.clientAtsign,
      'intents': instance.intents,
    };

PolicyResponse _$PolicyResponseFromJson(Map<String, dynamic> json) =>
    PolicyResponse(
      message: json['message'] as String?,
      policyInfos: (json['policies'] as List<dynamic>)
          .map((e) => PolicyInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$PolicyResponseToJson(PolicyResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'policies': instance.policyInfos,
    };

DeviceInfo _$DeviceInfoFromJson(Map<String, dynamic> json) => DeviceInfo(
      timestamp: (json['timestamp'] as num).toInt(),
      deviceAtsign: json['deviceAtsign'] as String,
      policyAtsign: json['policyAtsign'] as String?,
      devicename: json['devicename'] as String,
      deviceGroupName: json['deviceGroupName'] as String,
      managerAtsigns: (json['managerAtsigns'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
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
      'managerAtsigns': instance.managerAtsigns,
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
      eventType: $enumDecode(_$PolicyLogEventTypeEnumMap, json['eventType']),
      eventDetails: json['eventDetails'] as Map<String, dynamic>,
      message: json['message'] as String?,
    );

Map<String, dynamic> _$PolicyLogEventToJson(PolicyLogEvent instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp,
      'deviceAtsign': instance.deviceAtsign,
      'policyAtsign': instance.policyAtsign,
      'devicename': instance.devicename,
      'deviceGroupName': instance.deviceGroupName,
      'clientAtsign': instance.clientAtsign,
      'eventType': _$PolicyLogEventTypeEnumMap[instance.eventType]!,
      'message': instance.message,
      'eventDetails': instance.eventDetails,
    };

const _$PolicyLogEventTypeEnumMap = {
  PolicyLogEventType.requestFromDevice: 'requestFromDevice',
  PolicyLogEventType.responseToDevice: 'responseToDevice',
  PolicyLogEventType.deviceDecision: 'deviceDecision',
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
