import 'package:json_annotation/json_annotation.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/constants.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/util/uuid.dart';

part 'profile.g.dart';

@JsonSerializable()
final class Profile extends Loggable with Favoritable {
  // Manually handle the json for uuid since we only sometimes want it
  @JsonKey(defaultValue: '', includeToJson: false)
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

  Profile copyWith({
    String? uuid,
    String? displayName,
    String? relayAtsign,
    String? sshnpdAtsign,
    String? deviceName,
    String? remoteHost,
    int? remotePort,
    int? localPort,
  }) {
    return Profile(
      uuid ?? this.uuid,
      displayName: displayName ?? this.displayName,
      relayAtsign: relayAtsign ?? this.relayAtsign,
      sshnpdAtsign: sshnpdAtsign ?? this.sshnpdAtsign,
      deviceName: deviceName ?? this.deviceName,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
    );
  }

  /// Json but without the uuid
  Map<String, dynamic> toExportableJson() => _$ProfileToJson(this);

  Map<String, dynamic> toJson() {
    var json = _$ProfileToJson(this);
    json['uuid'] = uuid;
    return json;
  }

  factory Profile.fromJson(Map<String, dynamic> json, {String? uuid}) {
    var profile = _$ProfileFromJson(json);
    if (uuid != null || profile.uuid.isEmpty) {
      return profile.copyWith(uuid: uuid ?? Uuid.generate());
    }
    return profile;
  }

  @override
  List<Object?> get props => [
        uuid,
        displayName,
        relayAtsign,
        sshnpdAtsign,
        deviceName,
        remoteHost,
        remotePort,
        localPort,
      ];

  @override
  bool get stringify => true;

  NptParams toNptParams({
    required String clientAtsign,
    required String fallbackRelayAtsign,
    bool overrideRelayWithFallback = false,
  }) {
    String srvdAtSign = fallbackRelayAtsign;
    if (!overrideRelayWithFallback &&
        relayAtsign != null &&
        relayAtsign!.isNotEmpty) {
      srvdAtSign = relayAtsign!;
    }
    return NptParams(
      clientAtSign: clientAtsign,
      sshnpdAtSign: sshnpdAtsign,
      srvdAtSign: srvdAtSign,
      remoteHost: remoteHost,
      remotePort: remotePort,
      device: deviceName,
      localPort: localPort,
      rootDomain: Constants.rootDomain,

      // hardcoded for now, because it makes the app simpler
      // and there's very few use-cases where you wouldn't want these settings
      inline: true,
      timeout: const Duration(days: 1),
    );
  }

  @override
  String toString() {
    return 'Profile(displayName: $displayName, sshnpd: $sshnpdAtsign, '
        'deviceName: $deviceName, relayAtsign: $relayAtsign, uuid: $uuid)';
  }
}
