import 'dart:async';

import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_utils/at_logger.dart';
import 'package:at_utils/at_utils.dart';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/params/sshnp_params.dart';
import 'package:noports_core/src/common/supported_ssh_clients.dart';
import 'package:noports_core/src/common/utils.dart';
import 'package:noports_core/src/sshnp/sshnp_impl.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/src/sshrv/sshrv.dart';

abstract class SSHNP {
  abstract final AtSignLogger logger;

  // ====================================================================
  // Final instance variables, injected via constructor
  // ====================================================================
  /// The [AtClient] used to communicate with sshnpd and sshrvd
  abstract final AtClient atClient;

  /// The atSign of the sshnpd we wish to communicate with
  abstract final String sshnpdAtSign;

  /// The device name of the sshnpd we wish to communicate with
  abstract final String device;

  /// The user name on this host
  abstract final String username;

  /// The home directory on this host
  abstract final String homeDirectory;

  /// The sessionId we will use
  abstract final String sessionId;

  /// The name of the public key file from ~/.ssh which the client may request
  /// be appended to authorized_hosts on the remote device. Note that if the
  /// daemon on the remote device is not running with the `-s` flag, then it
  /// ignores such requests.
  abstract final String publicKeyFileName;

  abstract final List<String> localSshOptions;

  /// When false, we generate [sshPublicKey] and [sshPrivateKey] using ed25519.
  /// When true, we generate [sshPublicKey] and [sshPrivateKey] using RSA.
  /// Defaults to false
  abstract final bool rsa;

  // ====================================================================
  // Volatile instance variables, injected via constructor
  // but possibly modified later on
  // ====================================================================

  /// Host that we will send to sshnpd for it to connect to,
  /// or the atSign of the sshrvd.
  /// If using sshrvd then we will fetch the _actual_ host to use from sshrvd.
  abstract String host;

  /// Port that we will send to sshnpd for it to connect to.
  /// Required if we are not using sshrvd.
  /// If using sshrvd then initial port value will be ignored and instead we
  /// will fetch the port from sshrvd.
  abstract int port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  abstract int localPort;

  /// Port that local sshd is listening on localhost interface
  /// Default set to [defaultLocalSshdPort]
  abstract int localSshdPort;

  /// Port that the remote sshd is listening on localhost interface
  /// Default set to [defaultRemoteSshdPort]
  abstract int remoteSshdPort;

  // ====================================================================
  // Derived final instance variables, set during construction or init
  // ====================================================================

  /// Set to [AtClient.getCurrentAtSign] during construction
  @visibleForTesting
  abstract final String clientAtSign;

  /// The username to use on the remote host in the ssh session. Either passed
  /// through class constructor or fetched from the sshnpd
  /// by [fetchRemoteUserName] during [init]
  abstract String? remoteUsername;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will write
  /// [sshPublicKey] to ~/.ssh/authorized_keys
  abstract final String sshPublicKey;

  /// Set by [generateSshKeys] during [init].
  /// sshnp generates a new keypair for each ssh session, using ed25519 by
  /// default but rsa if the [rsa] flag is set to true. sshnp will send the
  /// [sshPrivateKey] to sshnpd
  abstract final String sshPrivateKey;

  /// Namespace will be set to [device].sshnp
  abstract final String namespace;

  /// When using sshrvd, this is fetched from sshrvd during [init]
  int get sshrvdPort;

  /// Set by constructor to
  /// '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}'
  abstract final String sshHomeDirectory;

  /// Function used to generate a [SSHRV] instance ([SSHRV.localBinary] by default)
  abstract final SSHRV Function(String, int) sshrvGenerator;

  /// true once we have received any response (success or error) from sshnpd
  @visibleForTesting
  abstract bool sshnpdAck;

  /// true once we have received an error response from sshnpd
  @visibleForTesting
  abstract bool sshnpdAckErrors;

  /// true once we have received a response from sshrvd
  @visibleForTesting
  abstract bool sshrvdAck;

  abstract final bool legacyDaemon;

  bool verbose = false;

  /// true once [init] has completed
  bool initialized = false;

  abstract final bool direct;

  /// If ssh tunnel is unused (no active connections via port forwards) for
  /// longer than this many seconds, then the connection will be closed.
  /// Defaults to [defaults.defaultIdleTimeout]
  abstract int idleTimeout;

  /// The ssh client to use when doing outbound ssh within this program
  abstract SupportedSshClient sshClient;

  /// When true, any local forwarding directives included in [localSshOptions]
  /// will be added to the initial tunnel ssh request
  abstract bool addForwardsToTunnel;

  /// Completes when the SSHNP instance is no longer doing anything
  /// e.g. controlling a direct ssh tunnel using the pure-dart SSHClient
  Future<void> get done;

  factory SSHNP({
    // final fields
    required AtClient atClient,
    required String sshnpdAtSign,
    required String device,
    required String username,
    required String homeDirectory,
    required String sessionId,
    String sendSshPublicKey = DefaultSSHNPArgs.sendSshPublicKey,
    required List<String> localSshOptions,
    bool rsa = false,
    // volatile fields
    required String host,
    required int port,
    required int localPort,
    String? remoteUsername,
    bool verbose = false,
    SSHRVGenerator sshrvGenerator = DefaultArgs.sshrvGenerator,
    int localSshdPort = DefaultArgs.localSshdPort,
    bool legacyDaemon = DefaultSSHNPArgs.legacyDaemon,
    int remoteSshdPort = DefaultArgs.remoteSshdPort,
    int idleTimeout = DefaultArgs.idleTimeout,
    required SupportedSshClient sshClient,
    required bool addForwardsToTunnel,
  }) {
    return SSHNPImpl(
      atClient: atClient,
      sshnpdAtSign: sshnpdAtSign,
      device: device,
      username: username,
      homeDirectory: homeDirectory,
      sessionId: sessionId,
      sendSshPublicKey: sendSshPublicKey,
      localSshOptions: localSshOptions,
      rsa: rsa,
      host: host,
      port: port,
      localPort: localPort,
      remoteUsername: remoteUsername,
      verbose: verbose,
      sshrvGenerator: sshrvGenerator,
      localSshdPort: localSshdPort,
      legacyDaemon: legacyDaemon,
      remoteSshdPort: remoteSshdPort,
      idleTimeout: idleTimeout,
      sshClient: sshClient,
      addForwardsToTunnel: addForwardsToTunnel,
    );
  }

  static Future<SSHNP> fromParams(
    SSHNPParams p, {
    AtClient? atClient,
    FutureOr<AtClient> Function(SSHNPParams, String)? atClientGenerator,
    void Function(Object, StackTrace)? usageCallback,
    SSHRVGenerator sshrvGenerator = SSHRV.localBinary,
  }) {
    return SSHNPImpl.fromParams(
      p,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
      usageCallback: usageCallback,
      sshrvGenerator: sshrvGenerator,
    );
  }

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
  Future<void> init();

  /// May only be run after [init] has been run.
  /// - Sends request to sshnpd; the response listener was started by [init]
  /// - Waits for success or error response, or time out after 10 secs
  /// - If got a success response, print the ssh command to use to stdout
  /// - Clean up temporary files
  Future<SSHNPResult> run();

  /// Send a ping out to all sshnpd and listen for heartbeats
  /// Returns two Iterable<String>:
  /// - Iterable<String> of atSigns of sshnpd that responded
  /// - Iterable<String> of atSigns of sshnpd that did not respond
  Future<(Iterable<String>, Iterable<String>, Map<String, dynamic>)>
      listDevices();
}
