import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

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
    required this.version,
    required this.corePackageVersion,
    required this.supportedFeatures,
    required this.allowedServices,
    this.status,
  });

  Map<String, dynamic> toJson() => _$DeviceInfoToJson(this);

  static DeviceInfo fromJson(Map<String, dynamic> json) =>
      _$DeviceInfoFromJson(json);
}

@JsonSerializable()
class PolicyLogEvent extends CoreDeviceInfo {
  final String clientAtsign;
  final bool authorized;
  final String? message;
  final List<String> permitOpen;

  PolicyLogEvent({
    required super.timestamp,
    required super.deviceAtsign,
    required super.policyAtsign,
    required super.devicename,
    required super.deviceGroupName,
    required this.clientAtsign,
    required this.authorized,
    required this.message,
    required this.permitOpen,
  });

  Map<String, dynamic> toJson() => _$PolicyLogEventToJson(this);

  static PolicyLogEvent fromJson(Map<String, dynamic> json) =>
      _$PolicyLogEventFromJson(json);
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
  // {
  //  "id":"xyz123",
  //  "name":"sysadmins",
  //  "userAtSigns":["@alice", ...],
  //  "daemonAtSigns":["@bob", ...],
  //  "devices":{
  //    "name":"some_device_name",
  //    "permitOpens":["localhost:3000", ...]
  //  },
  //  "deviceGroups":{
  //    "name":"some_device_group_name",
  //    "permitOpens":["localhost:3000", ...]
  //  }
  // }
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
