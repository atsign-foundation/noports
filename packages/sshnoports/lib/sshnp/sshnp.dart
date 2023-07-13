// dart packages
import 'dart:async';
import 'dart:io';

// atPlatform packages
import 'package:at_utils/at_logger.dart';
import 'package:at_client/at_client.dart';

// other packages
import 'package:meta/meta.dart';
import 'package:sshnoports/sshnp/sshnp_impl.dart';

// local packages

abstract class SSHNP {
  // TODO Make this a const in SSHRVD class
  static const String sshrvdNameSpace = 'sshrvd';

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

  abstract final String sendSshPublicKey;
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
  abstract String port;

  /// Port to which sshnpd will forwardRemote its [SSHClient]. If localPort
  /// is set to '0' then
  abstract String localPort;

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
  abstract final String nameSpace;

  /// When using sshrvd, this is fetched from sshrvd during [init]
  abstract final String sshrvdPort;

  /// Set to '$localPort $port $username $host $sessionId' during [init]
  abstract final String sshString;

  /// Set by constructor to
  /// '$homeDirectory${Platform.pathSeparator}.ssh${Platform.pathSeparator}'
  abstract final String sshHomeDirectory;

  /// true once we have received any response (success or error) from sshnpd
  @visibleForTesting
  abstract bool sshnpdAck;

  /// true once we have received an error response from sshnpd
  @visibleForTesting
  abstract bool sshnpdAckErrors;

  /// true once we have received a response from sshrvd
  @visibleForTesting
  abstract bool sshrvdAck;

  // In the future (perhaps) we can send other commands
  // Perhaps OpenVPN or shell commands
  static const String commandToSend = 'sshd';

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  factory SSHNP({
    // final fields
    required AtClient atClient,
    required String sshnpdAtSign,
    required String device,
    required String username,
    required String homeDirectory,
    required String sessionId,
    String sendSshPublicKey = 'false',
    required List<String> localSshOptions,
    bool rsa = false,
    // volatile fields
    required String host,
    required String port,
    required String localPort,
    String? remoteUsername,
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
    );
  }

  static Future<SSHNP> fromCommandLineArgs(List<String> args) async {
    return SSHNPImpl.fromCommandLineArgs(args);
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
  Future<void> run();

  /// Function which the response subscription (created in the [init] method
  /// will call when it gets a response from the sshnpd
  @visibleForTesting
  handleSshnpdResponses(notification) async {
    String notificationKey = notification.key
        .replaceAll('${notification.to}:', '')
        .replaceAll('.$device.sshnp${notification.from}', '')
        // convert to lower case as the latest AtClient converts notification
        // keys to lower case when received
        .toLowerCase();
    logger.info('Received $notificationKey notification');
    if (notification.value == 'connected') {
      logger.info('Session $sessionId connected successfully');
      sshnpdAck = true;
    } else {
      stderr.writeln('Remote sshnpd error: ${notification.value}');
      sshnpdAck = true;
      sshnpdAckErrors = true;
    }
  }

  /// Look up the user name ... we expect a key to have been shared with us by
  /// sshnpd. Let's say we are @human running sshnp, and @daemon is running
  /// sshnpd, then we expect a key to have been shared whose ID is
  /// @human:username.device.sshnp@daemon
  /// Is not called if remoteUserName was set via constructor
  Future<void> fetchRemoteUserName();

  Future<void> sharePublicKeyWithSshnpdIfRequired();

  Future<void> sharePrivateKeyWithSshnpd();

  Future<void> getHostAndPortFromSshrvd();

  Future<void> generateSshKeys();

  /// Return the command which this program should execute in order to start the
  /// sshrv program.
  /// - In normal usage, sshnp and sshrv are compiled to exe before use, thus the
  /// path is [Platform.resolvedExecutable] but with the last part (`sshnp` in
  /// this case) replaced with `sshrv`
  static String getSshrvCommand() {
    late String sshnpDir;
    List<String> pathList =
        Platform.resolvedExecutable.split(Platform.pathSeparator);
    if (pathList.last == 'sshnp' || pathList.last == 'sshnp.exe') {
      pathList.removeLast();
      sshnpDir = pathList.join(Platform.pathSeparator);

      return '$sshnpDir${Platform.pathSeparator}sshrv';
    } else {
      throw Exception(
          'sshnp is expected to be run as a compiled executable, not via the dart command');
    }
  }
}
