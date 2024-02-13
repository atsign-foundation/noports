import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/common/streaming_logging_handler.dart';
import 'package:noports_core/sshnp_foundation.dart';

abstract interface class SshnpRemoteProcess {
  Future<void> get done;

  Stream<List<int>> get stderr;

  StreamSink<List<int>> get stdin;

  Stream<List<int>> get stdout;
}

abstract interface class Sshnp {
  static final StreamingLoggingHandler _slh =
      StreamingLoggingHandler(AtSignLogger.defaultLoggingHandler);

  /// Legacy v3.x.x client
  @Deprecated(
      'Legacy unsigned client - only for connecting with ^3.0.0 daemons')
  factory Sshnp.unsigned({
    required AtClient atClient,
    required SshnpParams params,
  }) {
    AtSignLogger.defaultLoggingHandler = _slh;
    return SshnpUnsignedImpl(
        atClient: atClient, params: params, logStream: _slh.stream);
  }

  /// Think of this as the "default" client - calls openssh
  factory Sshnp.openssh({
    required AtClient atClient,
    required SshnpParams params,
  }) {
    AtSignLogger.defaultLoggingHandler = _slh;
    return SshnpOpensshLocalImpl(
        atClient: atClient, params: params, logStream: _slh.stream);
  }

  /// Uses a dartssh2 ssh client - requires that you pass in the identity keypair
  factory Sshnp.dartPure({
    required AtClient atClient,
    required SshnpParams params,
    required AtSshKeyPair? identityKeyPair,
  }) {
    AtSignLogger.defaultLoggingHandler = _slh;
    var sshnp = SshnpDartPureImpl(
        atClient: atClient,
        params: params,
        identityKeyPair: identityKeyPair,
        logStream: _slh.stream);
    if (identityKeyPair != null) {
      sshnp.keyUtil.addKeyPair(keyPair: identityKeyPair);
    }
    return sshnp;
  }

  /// The atClient to use for communicating with the atsign's secondary server
  AtClient get atClient;

  /// The parameters used to configure this Sshnp instance
  SshnpParams get params;

  /// May only be run after [initialize] has been run.
  /// - Sends request to srvd if required
  /// - Sends request to sshnpd; the response listener was started by [initialize]
  /// - Waits for success or error response, or time out after 10 secs
  /// - Make ssh tunnel connection using ephemeral keys
  Future<SshnpResult> run();

  /// May only be run after [run] has been run.
  /// When true, [runShell] will work.
  /// When false, runShell will throw an
  /// UnimplementedError
  bool get canRunShell;

  /// Creates a user ssh session on top of the tunnel session,
  /// and starts a shell.
  Future<SshnpRemoteProcess> runShell();

  /// Send a ping out to all sshnpd and listen for heartbeats
  /// Returns two Iterable<String> and a Map<String, dynamic>:
  /// - Iterable<String> of atSigns of sshnpd that responded
  /// - Iterable<String> of atSigns of sshnpd that did not respond
  /// - Map<String, dynamic> where the keys are all atSigns included in the maps, and the values being their device info
  Future<SshnpDeviceList> listDevices();

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the ssh connection.
  Stream<String>? get progressStream;

  /// Yields every log message that is written to [stderr]
  Stream<String>? get logStream;
}
