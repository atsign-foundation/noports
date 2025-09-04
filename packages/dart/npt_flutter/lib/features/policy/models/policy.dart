import 'package:json_annotation/json_annotation.dart';

part 'policy.g.dart';

/// Example of a Role object
/// {
///  "id": "3",
///  "name": "What Up",
///  "description": "Description!!!",
///  "daemonAtSigns": [
///    "@colin"
///  ],
///  "devices": [
///    {
///      "name": "Jeremy",
///      "permitOpens": [
///        "localhost:22",
///        "localhost:3389",
///        "127.0.0.1:22",
///        "127.0.0.1:3389"
///      ]
///    }
///  ],
///  "deviceGroups": [
///    {
///      "name": "jeremystuff",
///      "permitOpens": [
///        "localhost:22"
///      ]
///    }
///  ],
///  "userAtSigns": [
///    "@barbara"
///  ]
/// }

@JsonSerializable()
class Device {
  final String name;
  final List<String> permitOpens;

  Device({
    required this.name,
    required this.permitOpens,
  });

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

@JsonSerializable()
class DeviceGroup {
  final String name;
  List<String> permitOpens;

  DeviceGroup({
    required this.name,
    required this.permitOpens,
  });

  factory DeviceGroup.fromJson(Map<String, dynamic> json) => _$DeviceGroupFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceGroupToJson(this);
}

@JsonSerializable()
class Role {
  final String id;
  final String name;
  final String description;
  final List<String> daemonAtSigns;
  final List<Device> devices;
  final List<DeviceGroup> deviceGroups;
  final List<String> userAtSigns;

  factory Role.empty({
    required String id,
    required String name,
  }) {
    return Role(
      id: id,
      name: name,
      description: '',
      daemonAtSigns: [],
      devices: [],
      deviceGroups: [],
      userAtSigns: [],
    );
  }

  Role({
    required this.id,
    required this.name,
    required this.description,
    required this.daemonAtSigns,
    required this.devices,
    required this.deviceGroups,
    required this.userAtSigns,
  });

  factory Role.fromJson(Map<String, dynamic> json) => _$RoleFromJson(json);
  Map<String, dynamic> toJson() => _$RoleToJson(this);
}
