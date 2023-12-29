import 'dart:io';

import 'package:noports_core/src/sshrv/sshrv_impl.dart';
import 'package:socket_connector/socket_connector.dart';

abstract class Sshrv<T> {
  /// The internet address of the host to connect to.
  abstract final String host;

  /// The port of the host to connect to.
  abstract final int streamingPort;

  /// The local port to bridge to
  /// Defaults to 22
  abstract final int localPort;

  abstract final String? rvdAuthString;

  abstract final bool bindLocalPort;

  Future<T> run();

  // Can't use factory functions since SSHRV contains a generic type
  static Sshrv<Process> exec(
    String host,
    int streamingPort, {
    required int localPort,
    required bool bindLocalPort,
    String? rvdAuthString,
  }) {
    return SshrvImplExec(
      host,
      streamingPort,
      localPort: localPort,
      bindLocalPort: bindLocalPort,
      rvdAuthString: rvdAuthString,
    );
  }

  static Sshrv<SocketConnector> dart(
    String host,
    int streamingPort, {
    required int localPort,
    required bool bindLocalPort,
    String? rvdAuthString,
  }) {
    return SshrvImplDart(
      host,
      streamingPort,
      localPort: localPort,
      bindLocalPort: bindLocalPort,
      rvdAuthString: rvdAuthString,
    );
  }

  static Future<String?> getLocalBinaryPath() async {
    String postfix = Platform.isWindows ? '.exe' : '';
    List<String> pathList =
        Platform.resolvedExecutable.split(Platform.pathSeparator);
    bool isExe =
        (pathList.last == 'sshnp$postfix' || pathList.last == 'sshnpd$postfix');

    pathList
      ..removeLast()
      ..add('sshrv$postfix');

    File sshrvFile = File(pathList.join(Platform.pathSeparator));
    bool sshrvExists = await sshrvFile.exists();
    return (isExe && sshrvExists) ? sshrvFile.absolute.path : null;
  }
}
