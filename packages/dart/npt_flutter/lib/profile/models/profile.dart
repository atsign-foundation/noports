import 'package:json_annotation/json_annotation.dart';
import 'package:equatable/equatable.dart';
import 'package:noports_core/npt.dart';
import 'package:npt_flutter/env.dart';
import 'package:socket_connector/socket_connector.dart';

part 'profile.g.dart';

enum ProfileStatus { stopped, editing, starting, started, stopping }

@JsonSerializable(ignoreUnannotated: true)
final class Profile extends Equatable {
  // Variables we don't want to save
  final ProfileStatus status;
  final ProfileLogs? logs;
  //final Npt? npt;
  final SocketConnector? socketConnector;

  // Variables we do want to save
  @JsonKey()
  final String uuid;

  @JsonKey()
  final String displayName;

  @JsonKey()
  final String? relayAtsign;

  @JsonKey()
  final String sshnpdAtsign;

  @JsonKey()
  final String deviceName;

  @JsonKey()
  final String remoteHost;

  @JsonKey()
  final int remotePort;

  @JsonKey()
  final int localPort;

  const Profile(
    this.uuid, {
    required this.displayName,
    this.status = ProfileStatus.stopped,
    this.relayAtsign,
    required this.sshnpdAtsign,
    required this.deviceName,
    this.remoteHost = 'localhost',
    required this.remotePort,
    required this.localPort,
    this.logs,
    //this.npt,
    this.socketConnector,
  });

  Profile copyWith({
    String? uuid,
    String? displayName,
    ProfileStatus? status,
    String? relayAtsign,
    String? sshnpdAtsign,
    String? deviceName,
    String? remoteHost,
    int? remotePort,
    int? localPort,
    ProfileLogs? logs,
    //Npt? npt,
    SocketConnector? socketConnector,
  }) {
    return Profile(
      uuid ?? this.uuid,
      displayName: displayName ?? this.displayName,
      status: status ?? this.status,
      relayAtsign: relayAtsign ?? this.relayAtsign,
      sshnpdAtsign: sshnpdAtsign ?? this.sshnpdAtsign,
      deviceName: deviceName ?? this.deviceName,
      remoteHost: remoteHost ?? this.remoteHost,
      remotePort: remotePort ?? this.remotePort,
      localPort: localPort ?? this.localPort,
      logs: logs ?? this.logs,
      //npt: npt ?? this.npt,
      socketConnector: socketConnector ?? this.socketConnector,
    );
  }

  Map<String, dynamic> toJson() => _$ProfileToJson(this);
  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  @override
  List<Object?> get props => [
        uuid,
        displayName,
        status,
        relayAtsign,
        sshnpdAtsign,
        deviceName,
        remoteHost,
        remotePort,
        localPort,
        logs,
        //npt,
        socketConnector,
      ];

  @override
  bool get stringify => true;

  NptParams toNptParams({
    required String clientAtsign,
    required String fallbackRelayAtsign,
    String? overrideRelayAtsign,
  }) {
    return NptParams(
      clientAtSign: clientAtsign,
      sshnpdAtSign: sshnpdAtsign,
      srvdAtSign: overrideRelayAtsign ?? relayAtsign ?? fallbackRelayAtsign,
      remoteHost: remoteHost,
      remotePort: remotePort,
      device: deviceName,
      localPort: localPort,
      rootDomain: Env.rootDomain,

      // hardcoded for now, because it makes the app simpler
      // and there's very few use-cases where you wouldn't want these settings
      inline: true,
      timeout: const Duration(days: 1),
    );
  }
}

class ProfileLogs extends Equatable {
  final List<String> progress = <String>[];
  final List<String> errors = <String>[];
  ProfileLogs();

  void logProgress(String line) {
    progress.add(line);
  }

  void logError(String line) {
    errors.add(line);
  }

  @override
  List<Object?> get props => [progress, errors];
}
