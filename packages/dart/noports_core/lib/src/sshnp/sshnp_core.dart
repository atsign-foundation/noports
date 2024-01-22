import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/src/common/mixins/async_completion.dart';
import 'package:noports_core/src/common/mixins/async_initialization.dart';
import 'package:noports_core/src/common/mixins/at_client_bindings.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/util/sshnp_ssh_key_handler/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import 'package:noports_core/src/sshnp/util/srvd_channel/srvd_channel.dart';
import 'package:noports_core/sshnp.dart';
import 'package:uuid/uuid.dart';

// If you've never seen an abstract implementation before, here it is :P
@protected
abstract class SshnpCore
    with AsyncInitialization, AsyncDisposal, AtClientBindings, SshnpKeyHandler
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

  SshnpCore({
    required this.atClient,
    required this.params,
  })  : sessionId = Uuid().v4(),
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

    if (params.discoverDaemonFeatures) {
      late Map<String, dynamic> pingResponse;
      try {
        pingResponse =
            await sshnpdChannel.ping().timeout(Duration(seconds: 10));
      } catch (e) {
        logger.severe(
            'No ping response from ${params.device}${params.sshnpdAtSign}');
        rethrow;
      }

      final daemonFeatures = pingResponse['supportedFeatures'];
      if ((daemonFeatures[DaemonFeatures.srAuth.name] != true) &&
          (params.authenticateDeviceToRvd == true)) {
        throw ArgumentError('This device daemon does not support'
            ' authentication to the socket rendezvous.'
            ' Please set --no-authenticate-device');
      }
      if ((daemonFeatures[DaemonFeatures.srE2ee.name] != true) &&
          (params.encryptRvdTraffic == true)) {
        throw ArgumentError('This device daemon does not support'
            ' encryption of traffic to the socket rendezvous.'
            ' Please set --no-encrypt-rvd-traffic');
      }
    }

    /// Set the remote username to use for the ssh session
    remoteUsername = await sshnpdChannel.resolveRemoteUsername();

    /// Set the username to use for the initial ssh tunnel
    tunnelUsername = await sshnpdChannel.resolveTunnelUsername(
        remoteUsername: remoteUsername);

    /// Shares the public key if required
    await sshnpdChannel.sharePublicKeyIfRequired(identityKeyPair);

    /// Retrieve the srvd host and port pair
    await srvdChannel.callInitialization();
  }

  @override
  Future<void> dispose() async {
    completeDisposal();
  }

  @override
  Future<SshnpDeviceList> listDevices() => sshnpdChannel.listDevices();
}
