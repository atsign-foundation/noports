import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:noports_core/sshnp.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/favorite/favorite.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:npt_flutter/util/uuid.dart';

part 'profile.g.dart';

@JsonSerializable()
final class Profile extends Loggable with Favoritable {
  // Manually handle the json for uuid since we only sometimes want it
  @JsonKey(defaultValue: '', includeToJson: false)
  final String uuid;
  final String displayName;
  final Atsign? relayAtsign;
  final Atsign? sshnpdAtsign;
  final String deviceName;
  final String remoteHost;
  final int remotePort;
  final int localPort;
  @JsonKey(defaultValue: StringConst.localhost)
  final String localHost;
  final bool only443;
  final bool keepAlive;
  final String? connectUri;
  final String? connectUriProtocol;
  final String? connectUriUsername;

  // String get localHost => _localHost ?? StringConst.localhost;

  /// Constructs the full connection URI from protocol, username, localHost, and localPort
  String? get constructedConnectUri {
    // If protocol is explicitly set (even if empty), use it
    // Only fall back to manual connectUri if protocol was never set
    if (connectUriProtocol != null) {
      if (connectUriProtocol!.isEmpty) {
        return null; // Protocol explicitly set to "None"
      }

      final userPart =
          (connectUriUsername != null && connectUriUsername!.isNotEmpty)
          ? '$connectUriUsername@'
          : '';

      return '$connectUriProtocol://$userPart$localHost:$localPort';
    }

    // Fallback for old profiles that never had protocol field set
    return connectUri;
  }

  const Profile(
    this.uuid, {
    required this.displayName,
    this.relayAtsign,
    this.sshnpdAtsign,
    required this.deviceName,
    this.remoteHost = StringConst.localhost,
    required this.remotePort,
    required this.localPort,
    this.localHost = StringConst.localhost,
    this.only443 = false,
    this.keepAlive = false,
    this.connectUri,
    this.connectUriProtocol,
    this.connectUriUsername,
  });

  Profile copyWith({
    String? uuid,
    String? displayName,
    Atsign? relayAtsign,
    Atsign? sshnpdAtsign,
    String? deviceName,
    String? remoteHost,
    int? remotePort,
    int? localPort,
    String? localHost,
    bool? only443,
    Object? connectUriProtocol = _undefined,
    Object? connectUriUsername = _undefined,
    bool? keepAlive,
    Object? connectUri = _undefined,
  }) {
    return Profile(
      uuid ?? this.uuid,
      displayName: displayName ?? this.displayName,
      relayAtsign: relayAtsign ?? this.relayAtsign,
      sshnpdAtsign: sshnpdAtsign ?? this.sshnpdAtsign,
      deviceName: deviceName ?? this.deviceName,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
      localHost: localHost ?? this.localHost,
      localPort: localPort ?? this.localPort,
      only443: only443 ?? this.only443,
      keepAlive: keepAlive ?? this.keepAlive,
      connectUri: connectUri == _undefined
          ? this.connectUri
          : connectUri as String?,
      connectUriProtocol: connectUriProtocol == _undefined
          ? this.connectUriProtocol
          : connectUriProtocol as String?,
      connectUriUsername: connectUriUsername == _undefined
          ? this.connectUriUsername
          : connectUriUsername as String?,
    );
  }

  static const _undefined = Object();

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
    localHost,
    only443,
    keepAlive,
    connectUri,
    connectUriProtocol,
    connectUriUsername,
  ];

  @override
  bool get stringify => true;

  NptParams toNptParams({
    required Atsign clientAtsign,
    required String rootDomain,
    required Atsign fallbackRelayAtsign,
    bool overrideRelayWithFallback = false,
  }) {
    Atsign srvdAtsign = fallbackRelayAtsign;
    if (!overrideRelayWithFallback &&
        relayAtsign != null &&
        relayAtsign!.isNotEmpty) {
      srvdAtsign = relayAtsign!;
    }
    return NptParams(
      clientAtSign: clientAtsign,
      sshnpdAtSign: sshnpdAtsign!,
      srvdAtSign: srvdAtsign,
      remoteHost: remoteHost,
      remotePort: remotePort,
      device: deviceName,
      localPort: localPort,
      localHost: localHost,
      rootDomain: rootDomain,
      only443: only443,
      // When using 443, we must use ESCR relay auth mode
      relayAuthMode: only443 ? RelayAuthMode.escr : RelayAuthMode.payload,

      // hardcoded for now, because it makes the app simpler
      // and there's very few use-cases where you wouldn't want these settings
      inline: true,
      timeout: keepAlive ? const Duration(hours: 24) : const Duration(hours: 1),
    );
  }

  @override
  String toString() {
    return 'Profile(displayName: $displayName, sshnpd: $sshnpdAtsign, '
        'deviceName: $deviceName, relayAtsign: $relayAtsign, uuid: $uuid)';
  }
}
