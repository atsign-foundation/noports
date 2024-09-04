import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/srv.dart';

class DefaultArgs {
  static const String namespace = 'sshnp';
  @Deprecated("No longer used")
  static const String storagePathSubDirectory = '.sshnp';
  static const SupportedSshAlgorithm sshAlgorithm =
      SupportedSshAlgorithm.ed25519;
  static const bool verbose = false;
  static const bool quiet = false;
  static const String rootDomain = 'root.atsign.org';
  static const SrvGenerator srvGenerator = Srv.exec;
  static const int remoteSshdPort = 22;

  /// value in seconds after which idle ssh tunnels will be closed
  static const int idleTimeout = 15;
  static const bool help = false;
  static const bool addForwardsToTunnel = false;
  static final bool allowLocalFileSystem =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  static const bool authenticateClientToRvd = true;
  static const bool authenticateDeviceToRvd = true;
  static const bool encryptRvdTraffic = true;

  /// How long a client should wait for response after pinging a daemon
  static const int daemonPingTimeoutSeconds = 20;
  static const Duration daemonPingTimeoutDuration =
      Duration(seconds: daemonPingTimeoutSeconds);

  /// How long srv should stay running if SocketConnector has no connections
  static const int srvTimeoutInSeconds = 30;
  static const Duration srvTimeout = Duration(seconds: srvTimeoutInSeconds);
}

class DefaultSshnpArgs {
  static const String device = 'default';
  static const int localPort = 0;
  static const bool sendSshPublicKey = false;
  static const List<String> localSshOptions = <String>[];
  static const bool listDevices = false;
  static const SupportedSshClient sshClient = SupportedSshClient.openssh;
}

class DefaultSshnpdArgs {
  static const SupportedSshClient sshClient = SupportedSshClient.openssh;
  static const int localSshdPort = 22;
  static const String deviceGroupName = '__none__';
  static const String sshPublicKeyPermissions = "";
  static const Duration policyHeartbeatFrequency = const Duration(minutes: 5);
}
