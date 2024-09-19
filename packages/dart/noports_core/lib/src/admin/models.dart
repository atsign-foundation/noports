import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

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
