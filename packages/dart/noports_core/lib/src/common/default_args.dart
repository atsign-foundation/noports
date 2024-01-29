import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/src/common/types.dart';
import 'package:noports_core/srv.dart';

class DefaultArgs {
  static const String namespace = 'sshnp';
  static const String storagePathSubDirectory = '.sshnp';
  static const SupportedSshAlgorithm sshAlgorithm =
      SupportedSshAlgorithm.ed25519;
  static const bool verbose = false;
  static const String rootDomain = 'root.atsign.org';
  static const SrvGenerator srvGenerator = Srv.exec;
  static const int localSshdPort = 22;
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
  static const bool discoverDaemonFeatures = false;
}

class DefaultSshnpArgs {
  static const String device = 'default';
  static const int port = 22;
  static const int localPort = 0;
  static const bool sendSshPublicKey = false;
  static const List<String> localSshOptions = <String>[];
  static const bool legacyDaemon = false;
  static const bool listDevices = false;
  static const SupportedSshClient sshClient = SupportedSshClient.openssh;
}

class DefaultSshnpdArgs {
  static const SupportedSshClient sshClient = SupportedSshClient.openssh;
}
