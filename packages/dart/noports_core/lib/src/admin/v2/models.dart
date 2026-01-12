import 'package:json_annotation/json_annotation.dart';

part 'models.g.dart';

class PolicyEntry {
  String? id; 
  PolicyEntry({this.id});
}

// represents an individual client (e.g. "@colin", "Colin")
// each Client should have a unqiue atSign
@JsonSerializable()
class Client extends PolicyEntry {
  late String name;
  late String atSign; // unique

  Client({super.id, required this.name, required this.atSign});

  @override
  bool operator ==(Object other) {
    if(other is Client) {
      return atSign == other.atSign;
    }
    return identical(this, other);
  }

  @override
  int get hashCode => name.hashCode ^ atSign.hashCode;

  factory Client.fromJson(Map<String, dynamic> json) => _$ClientFromJson(json);
  Map<String, dynamic> toJson() => _$ClientToJson(this);

  bool isIdentical(final Client client) {
    return atSign == client.atSign;
  }
}

// represents a group of clients (e.g. "Atsign Engineers")
@JsonSerializable()
class ClientGroup extends PolicyEntry {
  late String name;

  ClientGroup({super.id, required this.name});

  factory ClientGroup.fromJson(Map<String, dynamic> json) => _$ClientGroupFromJson(json);
  Map<String, dynamic> toJson() => _$ClientGroupToJson(this);

  bool isIdentical(final ClientGroup clientGroup) {
    return name == clientGroup.name;
  }
}

// maps a client (e.g. @colin, "Colin) to a client group (e.g. "Atsign Engineers")
@JsonSerializable()
class ClientGroupMember extends PolicyEntry {
  late String clientId;
  late String clientGroupId;

  ClientGroupMember({super.id, required this.clientId, required this.clientGroupId});

  factory ClientGroupMember.fromJson(Map<String, dynamic> json) => _$ClientGroupMemberFromJson(json);
  Map<String, dynamic> toJson() => _$ClientGroupMemberToJson(this);
}

// represents a daemon atSign (e.g. "@daemon")
// each Daemon should have a unique atSign
@JsonSerializable()
class Daemon extends PolicyEntry {
  late String atSign;

  Daemon({super.id, required this.atSign});

  factory Daemon.fromJson(Map<String, dynamic> json) => _$DaemonFromJson(json);
  Map<String, dynamic> toJson() => _$DaemonToJson(this);
}

// maps daemon (e.g. "@dameon") to a device name (e.g. "macos")
// each Service should have a unique daemonId+deviceName+deviceGroupName 
@JsonSerializable()
class Service extends PolicyEntry {
  late String daemonId;
  late String deviceName; // can be `default`
  late String deviceGroupName; // can be `__none__`

  Service({
    super.id,
    required this.daemonId,
    required this.deviceName,
    required this.deviceGroupName});

  factory Service.fromJson(Map<String, dynamic> json) => _$ServiceFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceToJson(this);
}

// maps a service (e.g. "@daemon", "macos") to a client group (e.g. "Atsign Engineers") and ACL permitOpen (e.g. "localhost:22")
// each ServiceACL should have a unique serviceId+clientGroupId+permitOpen
@JsonSerializable()
class ServiceACL extends PolicyEntry {
  late String serviceId;
  late String clientGroupId;
  late String permitOpen;

  ServiceACL({super.id, required this.serviceId, required this.clientGroupId, required this.permitOpen});

  factory ServiceACL.fromJson(Map<String, dynamic> json) => _$ServiceACLFromJson(json);
  Map<String, dynamic> toJson() => _$ServiceACLToJson(this);
}

