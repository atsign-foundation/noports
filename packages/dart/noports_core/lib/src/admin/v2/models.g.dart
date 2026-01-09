// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Client _$ClientFromJson(Map<String, dynamic> json) => Client(
  id: json['id'] as String,
  name: json['name'] as String,
  atSign: json['atSign'] as String,
);

Map<String, dynamic> _$ClientToJson(Client instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'atSign': instance.atSign,
};

ClientGroup _$ClientGroupFromJson(Map<String, dynamic> json) =>
    ClientGroup(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$ClientGroupToJson(ClientGroup instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

ClientGroupMember _$ClientGroupMemberFromJson(Map<String, dynamic> json) =>
    ClientGroupMember(
      id: json['id'] as String,
      clientId: json['clientId'] as String,
      clientGroupId: json['clientGroupId'] as String,
    );

Map<String, dynamic> _$ClientGroupMemberToJson(ClientGroupMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'clientId': instance.clientId,
      'clientGroupId': instance.clientGroupId,
    };

Daemon _$DaemonFromJson(Map<String, dynamic> json) =>
    Daemon(id: json['id'] as String, atSign: json['atSign'] as String);

Map<String, dynamic> _$DaemonToJson(Daemon instance) => <String, dynamic>{
  'id': instance.id,
  'atSign': instance.atSign,
};

Service _$ServiceFromJson(Map<String, dynamic> json) => Service(
  id: json['id'] as String,
  daemonId: json['daemonId'] as String,
  deviceName: json['deviceName'] as String,
  deviceGroupName: json['deviceGroupName'] as String,
);

Map<String, dynamic> _$ServiceToJson(Service instance) => <String, dynamic>{
  'id': instance.id,
  'daemonId': instance.daemonId,
  'deviceName': instance.deviceName,
  'deviceGroupName': instance.deviceGroupName,
};

ServiceACL _$ServiceACLFromJson(Map<String, dynamic> json) => ServiceACL(
  id: json['id'] as String,
  serviceId: json['serviceId'] as String,
  clientGroupId: json['clientGroupId'] as String,
  permitOpen: json['permitOpen'] as String,
);

Map<String, dynamic> _$ServiceACLToJson(ServiceACL instance) =>
    <String, dynamic>{
      'id': instance.id,
      'serviceId': instance.serviceId,
      'clientGroupId': instance.clientGroupId,
      'permitOpen': instance.permitOpen,
    };
