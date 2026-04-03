import 'package:at_client/at_client.dart';
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

class AtsignConverter implements JsonConverter<Atsign, String> {
  const AtsignConverter();

  @override
  Atsign fromJson(String json) {
    return json.toAtsign();
  }

  @override
  String toJson(Atsign object) {
    return object;
  }
}

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
  final List<Atsign> daemonAtsigns;
  final List<Device> devices;
  final List<DeviceGroup> deviceGroups;
  final List<Atsign> userAtsigns;

  RoleInProgress({
    this.tempId,
    required this.name,
    required this.description,
    required this.daemonAtsigns,
    required this.devices,
    required this.deviceGroups,
    required this.userAtsigns,
  }) {
    tempId ??= Uuid.generate();
  }

  factory RoleInProgress.empty() {
    return RoleInProgress(
      name: '',
      description: '',
      daemonAtsigns: [],
      devices: [],
      deviceGroups: [],
      userAtsigns: [],
    );
  }

  RoleInProgress copyWith({
    String? tempId,
    String? name,
    String? description,
    List<Atsign>? daemonAtsigns,
    List<Device>? devices,
    List<DeviceGroup>? deviceGroups,
    List<Atsign>? userAtsigns,
  }) {
    return RoleInProgress(
      tempId: tempId ?? this.tempId,
      name: name ?? this.name,
      description: description ?? this.description,
      daemonAtsigns: daemonAtsigns ?? this.daemonAtsigns,
      devices: devices ?? this.devices,
      deviceGroups: deviceGroups ?? this.deviceGroups,
      userAtsigns: userAtsigns ?? this.userAtsigns,
    );
  }
}

/// Represents a Role that we fetched from an AtKey (id exists)
@JsonSerializable()
@AtsignConverter()
class FetchedRole extends RoleInProgress {
  final String id;

  FetchedRole({
    required this.id,
    required super.name,
    required super.description,
    @JsonKey(name: 'daemonAtSigns') required super.daemonAtsigns,
    required super.devices,
    required super.deviceGroups,
    @JsonKey(name: 'userAtSigns') required super.userAtsigns,
  }) : super(tempId: id);

  factory FetchedRole.fromRoleInProgress({
    required String id,
    required RoleInProgress roleInProgress,
  }) {
    return FetchedRole(
      id: id,
      name: roleInProgress.name,
      description: roleInProgress.description,
      daemonAtsigns: roleInProgress.daemonAtsigns,
      devices: roleInProgress.devices,
      deviceGroups: roleInProgress.deviceGroups,
      userAtsigns: roleInProgress.userAtsigns,
    );
  }

  factory FetchedRole.fromJson(Map<String, dynamic> json) =>
      _$FetchedRoleFromJson(json);
  Map<String, dynamic> toJson() => _$FetchedRoleToJson(this);

  @override
  FetchedRole copyWith({
    String? id,
    String? tempId,
    String? name,
    String? description,
    List<Atsign>? daemonAtsigns,
    List<Device>? devices,
    List<DeviceGroup>? deviceGroups,
    List<Atsign>? userAtsigns,
  }) {
    return FetchedRole(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      daemonAtsigns: daemonAtsigns ?? this.daemonAtsigns,
      devices: devices ?? this.devices,
      deviceGroups: deviceGroups ?? this.deviceGroups,
      userAtsigns: userAtsigns ?? this.userAtsigns,
    );
  }
}
