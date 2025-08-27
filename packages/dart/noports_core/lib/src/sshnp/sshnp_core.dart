import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/src/common/mixins/async_completion.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/util/sshnp_ssh_key_handler/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/sshnp.dart';
import 'package:uuid/uuid.dart';

// If you've never seen an abstract implementation before, here it is :P
@protected
abstract class SshnpCore
    with
        AsyncInitialization,
        AsyncDisposal,
        AtClientBindings,
        SshnpKeyHandler,
        ApkamSigning
    implements Sshnp {
  // * AtClientBindings members
  /// The logger for this class
  @override
  final AtSignLogger logger = AtSignLogger('Sshnp');

  /// The [AtClient] to use for this instance
  @override
  final AtClient atClient;

  // * Main Parameters

  /// The parameters supplied for this instance
  @override
  final SshnpParams params;

  /// The session ID for this instance (UUID v4)
  final String sessionId;

  /// The namespace for this instance ('[params.device].sshnp')
  final String namespace;

  // * Volatile State
  /// The local port to use for the initial tunnel's sshd forwarding
  /// If this is 0, then a spare port will be found and set
  int localPort;

  /// The remote username to use for the ssh session
  String? remoteUsername;

  /// The username to use for the initial ssh tunnel session
  String? tunnelUsername;

  // * Communication Channels

  /// The channel to communicate with the srvd (host)
  @protected
  SrvdChannel get srvdChannel;

  /// The channel to communicate with the sshnpd (daemon)
  @protected
  SshnpdChannel get sshnpdChannel;

  final StreamController<String> _progressStreamController =
      StreamController<String>.broadcast();

  /// Yields a string every time something interesting happens with regards to
  /// progress towards establishing the ssh connection.
  @override
  Stream<String>? get progressStream => _progressStreamController.stream;

  /// Yields every log message that is written to [stderr]
  @override
  final Stream<String>? logStream;

  /// Subclasses should use this method to generate progress messages
  sendProgress(String message) {
    _progressStreamController.add(message);
  }

  /// the uri (e.g. public:foo.bar.baz@atsign) of the [publicSigningKey]
  @override
  String get publicSigningKeyUri;

  /// the public key which can be used to verify signatures made using
  /// [privateSigningKey]
  @override
  String get publicSigningKey;

  /// the private key used to sign things this program sends
  @override
  String get privateSigningKey;

  SshnpCore({required this.atClient, required this.params, this.logStream})
      : sessionId = Uuid().v4(),
        namespace = '${params.device}.${DefaultArgs.namespace}',
        localPort = params.localPort {
    logger.level = params.verbose ? 'info' : 'shout';

    /// Set the namespace to the device's namespace
    AtClientPreference preference =
        atClient.getPreferences() ?? AtClientPreference();
    preference.namespace = namespace;
    atClient.setPreferences(preference);
  }

  @override
  @mustCallSuper
  Future<void> initialize() async {
    if (!isSafeToInitialize) return;

    logger.info('Initializing SshnpCore');

    /// Start the sshnpd payload handler
    await sshnpdChannel.callInitialization();

    /// Send ping to the daemon to discover its supported features. Note that
    /// we only wait for the ping response **after** we have completed our
    /// interaction with the srvd; as a result the ping causes no increase in
    /// overall time-to-session-started
    List<DaemonFeature> requiredFeatures = [];
    if (params.authenticateDeviceToRvd) {
      requiredFeatures.add(DaemonFeature.srAuth);
    }
    if (params.encryptRvdTraffic) {
      requiredFeatures.add(DaemonFeature.srE2ee);
    }
    if (params.sendSshPublicKey) {
      requiredFeatures.add(DaemonFeature.acceptsPublicKeys);
    }
    if (params.relayAuthMode == RelayAuthMode.escr) {
      requiredFeatures.add(DaemonFeature.supportsRamEscr);
    }
    sendProgress('Sending daemon feature check request');

    Future<List<(DaemonFeature feature, bool supported, String reason)>>
        featureCheckFuture = sshnpdChannel.featureCheck(
      requiredFeatures,
      timeout: params.daemonPingTimeout,
    );

    /// Set the remote username to use for the ssh session
    sendProgress('Resolving remote username for user session');
    remoteUsername = await sshnpdChannel.resolveRemoteUsername();

    /// Set the username to use for the initial ssh tunnel
    sendProgress('Resolving remote username for tunnel session');
    tunnelUsername = await sshnpdChannel.resolveTunnelUsername(
      remoteUsername: remoteUsername,
    );

    /// Shares the public key if required
    if (params.sendSshPublicKey) {
      sendProgress('Sharing ssh public key');
    }
    await sshnpdChannel.sharePublicKeyIfRequired(identityKeyPair);

    if (sshnpdChannel.cachedPingResponse != null) {
      srvdChannel.cachedDaemonPublicSigningKeyUri =
          sshnpdChannel.cachedPingResponse!['publicSigningKeyUri'];
    }

    /// Retrieve the srvd host and port pair
    sendProgress('Fetching host and port from srvd');
    await srvdChannel.callInitialization();
    sendProgress('Received host and port from srvd');

    sendProgress('Waiting for daemon feature check response');
    List<(DaemonFeature, bool, String)> features = await featureCheckFuture;
    sendProgress('Received daemon feature check response');

    await Future.delayed(Duration(milliseconds: 1));
    for (final (DaemonFeature _, bool supported, String reason) in features) {
      if (!supported) throw SshnpError(reason);
    }
    sendProgress('Required daemon features are supported');
  }

  @override
  Future<void> dispose() async {
    completeDisposal();
  }

  @override
  Future<SshnpDeviceList> listDevices({
    Duration waitDuration = Sshnp.defaultListDevicesWaitTime,
  }) =>
      sshnpdChannel.listDevices(waitDuration: waitDuration);
}
