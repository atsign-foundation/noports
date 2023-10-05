import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/src/sshnp/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_params/sshnp_params.dart';
import 'package:noports_core/src/sshrv/sshrv.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';

typedef AtClientGenerator = FutureOr<AtClient> Function(
    SSHNPParams params, String namespace);

typedef UsageCallback = void Function(Object error, StackTrace stackTrace);

abstract class SSHNP {
  static Future<SSHNP> fromParams(
    SSHNPParams params, {
    AtClient? atClient,
    AtClientGenerator? atClientGenerator,
    SSHRVGenerator? sshrvGenerator,
    bool? shouldInitialize,
  }) async {
    atClient ??= await atClientGenerator?.call(
        params, SSHNPImpl.getNamespace(params.device));

    if (atClient == null) {
      throw ArgumentError(
          'atClient must be provided or atClientGenerator must be provided');
    }

    if (params.legacyDaemon) {
      return SSHNP.legacy(
        atClient: atClient,
        params: params,
        sshrvGenerator: sshrvGenerator,
        shouldInitialize: shouldInitialize,
      );
    }

    if (!params.host.startsWith('@')) {
      return SSHNP.reverse(
        atClient: atClient,
        params: params,
        sshrvGenerator: sshrvGenerator,
        shouldInitialize: shouldInitialize,
      );
    }

    switch (params.sshClient) {
      case SupportedSshClient.exec:
        return SSHNP.forwardExec(
          atClient: atClient,
          params: params,
          shouldInitialize: shouldInitialize,
        );
      case SupportedSshClient.dart:
        return SSHNP.forwardDart(
          atClient: atClient,
          params: params,
          shouldInitialize: shouldInitialize,
        );
    }
  }

  /// Creates an SSHNP instance that is configured to communicate with legacy >= 3.0.0 <4.0.0 daemons
  factory SSHNP.legacy({
    required AtClient atClient,
    required SSHNPParams params,
    SSHRVGenerator? sshrvGenerator,
    bool? shouldInitialize,
  }) =>
      SSHNPLegacyImpl(
        atClient: atClient,
        params: params,
        sshrvGenerator: sshrvGenerator,
        shouldInitialize: shouldInitialize,
      );

  /// Creates an SSHNP instance that is configured to use reverse ssh tunneling
  factory SSHNP.reverse({
    required AtClient atClient,
    required SSHNPParams params,
    SSHRVGenerator? sshrvGenerator,
    bool? shouldInitialize,
  }) =>
      SSHNPReverseImpl(
        atClient: atClient,
        params: params,
        sshrvGenerator: sshrvGenerator,
        shouldInitialize: shouldInitialize,
      );

  /// Creates an SSHNP instance that is configured to use direct ssh tunneling by executing the ssh command
  factory SSHNP.forwardExec({
    required AtClient atClient,
    required SSHNPParams params,
    bool? shouldInitialize,
  }) =>
      SSHNPForwardExecImpl(
        atClient: atClient,
        params: params,
        shouldInitialize: shouldInitialize,
      );

  /// Creates an SSHNP instance that is configured to use direct ssh tunneling using a pure-dart SSHClient
  factory SSHNP.forwardDart({
    required AtClient atClient,
    required SSHNPParams params,
    bool? shouldInitialize,
  }) =>
      SSHNPForwardDartImpl(
        atClient: atClient,
        params: params,
        shouldInitialize: shouldInitialize,
      );

  /// The atClient to use for communicating with the atsign's secondary server
  AtClient get atClient;

  /// The parameters used to configure this SSHNP instance
  SSHNPParams get params;

  /// Completes when the SSHNP instance is no longer doing anything
  /// e.g. controlling a direct ssh tunnel using the pure-dart SSHClient
  Future<void> get done;

  /// Completes after asynchronous initialization has completed
  Future<void> get initialized;

  /// Must be run after construction, to complete initialization
  /// - Starts notification subscription to listen for responses from sshnpd
  /// - calls [generateSshKeys] which generates the ssh keypair to use
  ///   ( [sshPublicKey] and [sshPrivateKey] )
  /// - calls [fetchRemoteUserName] to fetch the username to use on the remote
  ///   host in the ssh session
  /// - If not supplied via constructor, finds a spare port for [localPort]
  /// - If using sshrv, calls [getHostAndPortFromSshrvd] to fetch host and port
  ///   from sshrvd
  /// - calls [sharePrivateKeyWithSshnpd]
  /// - calls [sharePublicKeyWithSshnpdIfRequired]
  FutureOr<void> init();

  /// May only be run after [init] has been run.
  /// - Sends request to sshnpd; the response listener was started by [init]
  /// - Waits for success or error response, or time out after 10 secs
  /// - If got a success response, print the ssh command to use to stdout
  /// - Clean up temporary files
  FutureOr<SSHNPResult> run();

  /// Send a ping out to all sshnpd and listen for heartbeats
  /// Returns two Iterable<String> and a Map<String, dynamic>:
  /// - Iterable<String> of atSigns of sshnpd that responded
  /// - Iterable<String> of atSigns of sshnpd that did not respond
  /// - Map<String, dynamic> where the keys are all atSigns included in the maps, and the values being their device info
  FutureOr<(Iterable<String>, Iterable<String>, Map<String, dynamic>)>
      listDevices();

  /// - Dispose of any resources used by this SSHNP instance
  /// - Clean up temporary files
  FutureOr<void> cleanUp();
}
