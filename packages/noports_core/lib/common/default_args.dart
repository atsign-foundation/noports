import 'package:noports_core/common/supported_ssh_clients.dart';
import 'package:noports_core/sshrv/sshrv.dart';

class DefaultArgs {
  const DefaultArgs();

  static const verbose = false;
  static const rsa = false;
  static const rootDomain = 'root.atsign.org';
  static const sshrvGenerator = SSHRV.localBinary;
  static const localSshdPort = 22;
  static const remoteSshdPort = 22;

  /// value in seconds after which idle ssh tunnels will be closed
  static const idleTimeout = 15;
}

class DefaultSSHNPArgs {
  static const device = 'default';
  static const port = 22;
  static const localPort = 0;
  static const sendSshPublicKey = '';
  static const localSshOptions = <String>[];
  static const legacyDaemon = true;
  static const listDevices = false;
  static const sshClient = SupportedSshClient.hostSsh;
}
