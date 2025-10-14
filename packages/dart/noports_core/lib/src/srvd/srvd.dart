import 'dart:async';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';

abstract interface class Srvd {
  static const String namespace = 'sshrvd';

  abstract final AtSignLogger logger;
  abstract AtClient atClient;
  abstract final String atSign;
  abstract final String homeDirectory;
  abstract final String atKeysFilePath;
  abstract final String managerAtsign;
  abstract final String ipAddress;
  abstract final bool logTraffic;
  abstract final bool bind443;
  abstract final int localBindPort443;
  abstract bool verbose;

  /// true once [init] has completed
  @visibleForTesting
  abstract bool initialized;

  static Future<Srvd> fromCommandLineArgs(
    List<String> args, {
    AtClient? atClient,
    FutureOr<AtClient> Function(SrvdParams)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
  }) async {
    return SrvdImpl.fromCommandLineArgs(
      args,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
      usageCallback: usageCallback,
    );
  }

  Future<void> init();

  Future<void> run();

  Future<void> lookup(IIRequest msg, SendPort toSpawned);

  Future<(PortPair, Isolate, SendPort)> spawnNewPortPairIsolate(
    SrvdSessionParams sessionParams,
  );

  Future<(PortPair, Isolate, SendPort)> spawnNewSinglePortIsolate(
    String address,
    bool useTLS,
    int bindPort,
  );
}
