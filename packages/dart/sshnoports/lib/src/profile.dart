import 'package:json_annotation/json_annotation.dart';

part 'profile.g.dart';

@JsonSerializable()
final class Profile {
  final String uuid;
  final String displayName;
  final String? relayAtsign;
  final String sshnpdAtsign;
  final String deviceName;
  final String remoteHost;
  final int remotePort;
  final int localPort;

  const Profile(
    this.uuid, {
    required this.displayName,
    this.relayAtsign,
    required this.sshnpdAtsign,
    required this.deviceName,
    this.remoteHost = 'localhost',
    required this.remotePort,
    required this.localPort,
  });

  Map<String, dynamic> toJson() => _$ProfileToJson(this);

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  @override
  String toString() {
    return 'Profile(displayName: $displayName, sshnpd: $sshnpdAtsign, '
        'deviceName: $deviceName, relayAtsign: $relayAtsign, uuid: $uuid)';
  }
}
