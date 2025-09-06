import 'package:json_annotation/json_annotation.dart';
import 'package:npt_flutter/util/uuid.dart';

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

  Device({required this.name, required this.permitOpens});

  factory Device.fromJson(Map<String, dynamic> json) => _$DeviceFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceToJson(this);
}

@JsonSerializable()
class DeviceGroup {
  final String name;
  List<String> permitOpens;

  DeviceGroup({required this.name, required this.permitOpens});

  factory DeviceGroup.fromJson(Map<String, dynamic> json) =>
      _$DeviceGroupFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceGroupToJson(this);
}

/// Similar to FetchedRole, but no id
/// This class represents a Role that the user may be currently editing but unfinished.
class RoleInProgress {
  String? tempId; // temporary id for UI purposes only
  final String name;
  final String description;
  final List<String> daemonAtSigns;
  final List<Device> devices;
  final List<DeviceGroup> deviceGroups;
  final List<String> userAtSigns;

  RoleInProgress({
    this.tempId,
    required this.name,
    required this.description,
    required this.daemonAtSigns,
    required this.devices,
    required this.deviceGroups,
    required this.userAtSigns,
  }) {
    tempId ??= Uuid.generate();
  }

  factory RoleInProgress.empty() {
    return RoleInProgress(
      name: '',
      description: '',
      daemonAtSigns: [],
      devices: [],
      deviceGroups: [],
      userAtSigns: [],
    );
  }
}

/// Represents a Role that we fetched from an AtKey (id exists)
@JsonSerializable()
class FetchedRole extends RoleInProgress {
  final String id;

  FetchedRole({
    required this.id,
    required super.name,
    required super.description,
    required super.daemonAtSigns,
    required super.devices,
    required super.deviceGroups,
    required super.userAtSigns,
  }) : super(tempId: id);

  factory FetchedRole.fromRoleInProgress({
    required String id,
    required RoleInProgress roleInProgress,
  }) {
    return FetchedRole(
      id: id,
      name: roleInProgress.name,
      description: roleInProgress.description,
      daemonAtSigns: roleInProgress.daemonAtSigns,
      devices: roleInProgress.devices,
      deviceGroups: roleInProgress.deviceGroups,
      userAtSigns: roleInProgress.userAtSigns,
    );
  }

  factory FetchedRole.fromJson(Map<String, dynamic> json) =>
      _$FetchedRoleFromJson(json);
  Map<String, dynamic> toJson() => _$FetchedRoleToJson(this);
}
