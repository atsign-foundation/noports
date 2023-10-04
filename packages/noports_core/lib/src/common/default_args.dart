import 'dart:io';

import 'package:noports_core/src/common/supported_ssh_clients.dart';
import 'package:noports_core/sshrv.dart';

class DefaultArgs {
  const DefaultArgs();

  static const String namespace = 'sshnp';

  static const bool verbose = false;
  static const bool rsa = false;
  static const String rootDomain = 'root.atsign.org';
  static const SSHRVGenerator sshrvGenerator = SSHRV.exec;
  static const int localSshdPort = 22;
  static const int remoteSshdPort = 22;

  /// value in seconds after which idle ssh tunnels will be closed
  static const int idleTimeout = 15;
  static const bool help = false;
  static const bool addForwardsToTunnel = false;
  static final bool allowLocalFileSystem =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
}

class DefaultSSHNPArgs {
  static const String device = 'default';
  static const int port = 22;
  static const int localPort = 0;
  static const bool sendSshPublicKey = false;
  static const List<String> localSshOptions = <String>[];
  static const bool legacyDaemon = false;
  static const bool listDevices = false;
  static String getSshClient(bool? allowLocalFileSystem) =>
      allowLocalFileSystem ?? DefaultArgs.allowLocalFileSystem
          ? SupportedSshClient.exec.cliArg
          : SupportedSshClient.dart.cliArg;
}

class DefaultSSHNPDArgs {
  static const SupportedSshClient sshClient = SupportedSshClient.exec;
}
