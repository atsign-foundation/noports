import 'package:json_annotation/json_annotation.dart';

part 'policy.g.dart';

@JsonSerializable()
class DeviceAtSign {
  final String atSign;

  DeviceAtSign({
    required this.atSign,
  });

  factory DeviceAtSign.fromJson(Map<String, dynamic> json) => _$DeviceAtSignFromJson(json);
  Map<String, dynamic> toJson() => _$DeviceAtSignToJson(this);
}

@JsonSerializable()
class UserAtSign {
  final String atSign;

  UserAtSign({
    required this.atSign,
  });

  factory UserAtSign.fromJson(Map<String, dynamic> json) => _$UserAtSignFromJson(json);
  Map<String, dynamic> toJson() => _$UserAtSignToJson(this);
}

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
  String? id;
  final String name;
  final String description;
  final List<DeviceAtSign> deviceAtSigns;
  final List<Device> deviceNames;
  final List<DeviceGroup> deviceGroups;
  final List<UserAtSign> userAtSigns;

  factory Role.empty({
    String? id,
    required String name,
  }) {
    return Role(
      id: id,
      description: '',
      name: name,
      deviceAtSigns: [],
      deviceNames: [],
      deviceGroups: [],
      userAtSigns: [],
    );
  }

  Role({
    this.id,
    required this.name,
    required this.description,
    required this.deviceAtSigns,
    required this.deviceNames,
    required this.deviceGroups,
    required this.userAtSigns,
  });

  factory Role.fromJson(Map<String, dynamic> json) => _$RoleFromJson(json);
  Map<String, dynamic> toJson() => _$RoleToJson(this);
}
