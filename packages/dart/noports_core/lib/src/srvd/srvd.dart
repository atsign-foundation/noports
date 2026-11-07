import 'dart:async';
import 'dart:isolate';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/isolates/types.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';
import 'package:noports_core/src/srvd/srvd_session_params.dart';

abstract interface class Srvd {
  static const String namespace = 'sshrvd';

  /// The most [stop] takes, whatever the sessions do. A deployment's
  /// termination grace period must allow it.
  static const Duration stopBound = Duration(seconds: 12);

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

  bool wellFormedRequest(AtNotification n, {bool throwIfFalse = false});

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

  /// Stops what [init] and [run] started: cancels the notification
  /// subscriptions, closes every session's connections, waits for each
  /// worker to report its session complete, and ends every relay isolate,
  /// within [stopBound]. The [atClient] stays open for whoever owns it.
  Future<void> stop();

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
