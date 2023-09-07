import 'dart:io';

import 'package:at_utils/at_utils.dart';
import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

part 'sshrv_impl.dart';

typedef SSHRVGenerator = SSHRV Function(String, int, {int localSshdPort});

abstract class SSHRV<T> {
  /// The internet address of the host to connect to.
  abstract final String host;

  /// The port of the host to connect to.
  abstract final int streamingPort;

  /// The local sshd port
  /// Defaults to 22
  abstract final int localSshdPort;

  Future<T> run();

  // Can't use factory functions since SSHRV contains a generic type
  static SSHRV<Process> localBinary(
    String host,
    int streamingPort, {
    int localSshdPort = SSHNP.defaultLocalSshdPort,
  }) {
    return SSHRVImpl(
      host,
      streamingPort,
      localSshdPort: localSshdPort,
    );
  }

  static SSHRV<SocketConnector> pureDart(
    String host,
    int streamingPort, {
    int localSshdPort = 22,
  }) {
    return SSHRVImplPureDart(
      host,
      streamingPort,
      localSshdPort: localSshdPort,
    );
  }

  static Future<String?> getLocalBinaryPath() async {
    String postfix = Platform.isWindows ? '.exe' : '';
    List<String> pathList =
        Platform.resolvedExecutable.split(Platform.pathSeparator);
    bool isExe = (pathList.last == 'sshnp$postfix');

    pathList
      ..removeLast()
      ..add('sshrv$postfix');

    File sshrvFile = File(pathList.join(Platform.pathSeparator));
    bool sshrvExists = await sshrvFile.exists();
    return (isExe && sshrvExists) ? sshrvFile.absolute.path : null;
  }
}
