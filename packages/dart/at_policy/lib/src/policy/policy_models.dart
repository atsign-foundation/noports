import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:json_annotation/json_annotation.dart';

part 'policy_models.g.dart';

const JsonEncoder jsonPrettyPrinter = JsonEncoder.withIndent('    ');

@JsonSerializable()
class PolicyIntent {
  final String intent;
  final Map<String, dynamic>? params;

  PolicyIntent({
    required this.intent,
    this.params,
  });

  Map<String, dynamic> toJson() => _$PolicyIntentToJson(this);

  static PolicyIntent fromJson(Map<String, dynamic> json) =>
      _$PolicyIntentFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

@JsonSerializable()
class PolicyInfo {
  final String intent;
  Map<String, dynamic> info;

  PolicyInfo({
    required this.intent,
    required this.info,
  });

  Map<String, dynamic> toJson() => _$PolicyInfoToJson(this);

  static PolicyInfo fromJson(Map<String, dynamic> json) =>
      _$PolicyInfoFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

@JsonSerializable()
class PolicyRequest {
  final String daemonAtsign;
  final String daemonDeviceName;
  final String daemonDeviceGroupName;
  final String clientAtsign;
  final List<PolicyIntent> intents;

  PolicyRequest({
    required this.daemonAtsign,
    required this.daemonDeviceName,
    required this.daemonDeviceGroupName,
    required this.clientAtsign,
    required this.intents,
  });

  Map<String, dynamic> toJson() => _$PolicyRequestToJson(this);

  static PolicyRequest fromJson(Map<String, dynamic> json) =>
      _$PolicyRequestFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

@JsonSerializable()
class PolicyResponse {
  final String? message;
  final List<PolicyInfo> policyInfos;

  PolicyResponse({
    required this.message,
    required this.policyInfos,
  }) {
    Set<String> intents = {};
    for (final i in policyInfos) {
      if (intents.contains(i.intent)) {
        throw IllegalArgumentException('More than one PolicyInfo provided for intent: ${i.intent}');
      } else {
        intents.add(i.intent);
      }
    }
  }

  PolicyInfo? infoForIntent(String intent) {
    for (final i in policyInfos) {
      if (i.intent == intent) {
        return i;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => _$PolicyResponseToJson(this);

  static PolicyResponse fromJson(Map<String, dynamic> json) =>
      _$PolicyResponseFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

abstract class CoreDeviceInfo {
  final int timestamp;
  final String deviceAtsign;
  final String? policyAtsign;
  final String devicename;
  final String deviceGroupName;

  CoreDeviceInfo({
    required this.timestamp,
    required this.deviceAtsign,
    required this.policyAtsign,
    required this.devicename,
    required this.deviceGroupName,
  });
}

@JsonSerializable()
class DeviceInfo extends CoreDeviceInfo {
  final List<String> managerAtsigns;
  final String version;
  final String corePackageVersion;
  final Map<String, dynamic> supportedFeatures;
  final List<String> allowedServices; // aka permitOpens
  String? status;

  DeviceInfo({
    required super.timestamp,
    required super.deviceAtsign,
    required super.policyAtsign,
    required super.devicename,
    required super.deviceGroupName,
    required this.managerAtsigns,
    required this.version,
    required this.corePackageVersion,
    required this.supportedFeatures,
    required this.allowedServices,
    this.status,
  });

  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  static DeviceInfo fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

enum PolicyLogEventType {
  requestFromDevice,
  responseToDevice,
  deviceDecision,
}

@JsonSerializable()
class PolicyLogEvent extends CoreDeviceInfo {
  final String clientAtsign;
  final PolicyLogEventType eventType;
  final String? message;
  final Map<String, dynamic> eventDetails;

  PolicyLogEvent({
    required super.timestamp,
    required super.deviceAtsign,
    required super.policyAtsign,
    required super.devicename,
    required super.deviceGroupName,
    required this.clientAtsign,
    required this.eventType,
    required this.eventDetails,
    required this.message,
  });

  Map<String, dynamic> toJson() => _$PolicyLogEventToJson(this);

  static PolicyLogEvent fromJson(Map<String, dynamic> json) =>
      _$PolicyLogEventFromJson(json);

  @override
  String toString() => jsonPrettyPrinter.convert(toJson());
}

@JsonSerializable()
class Device {
  final String name;

  final List<String> permitOpens;

  Device({
    required this.name,
    required this.permitOpens,
  });

  Map<String, dynamic> toJson() => _$DeviceToJson(this);

  static Device fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
}

@JsonSerializable()
class DeviceGroup {
  final String name;

  List<String> permitOpens;

  DeviceGroup({
    required this.name,
    required this.permitOpens,
  });

  Map<String, dynamic> toJson() => _$DeviceGroupToJson(this);

  static DeviceGroup fromJson(Map<String, dynamic> json) =>
      _$DeviceGroupFromJson(json);
}

@JsonSerializable()
class UserGroup {
  String? id;
  final String name;
  final String description;

  final List<String> daemonAtSigns;

  final List<Device> devices;

  final List<DeviceGroup> deviceGroups;

  final List<String> userAtSigns;

  factory UserGroup.empty(
      {String? id, required String name, required String description}) {
    return UserGroup(
        id: id,
        name: name,
        description: description,
        userAtSigns: [],
        daemonAtSigns: [],
        devices: [],
        deviceGroups: []);
  }

  UserGroup({
    this.id,
    required this.name,
    required this.description,
    required this.userAtSigns,
    required this.daemonAtSigns,
    required this.devices,
    required this.deviceGroups,
  });

  Map<String, dynamic> toJson() => _$UserGroupToJson(this);

  static UserGroup fromJson(Map<String, dynamic> json) =>
      _$UserGroupFromJson(json);
}
