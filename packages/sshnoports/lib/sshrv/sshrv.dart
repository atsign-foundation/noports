import 'dart:io';

import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';

part 'sshrv_impl.dart';

abstract class SSHRV<T> {
  /// The internet address of the host to connect to.
  abstract final String host;

  /// The port of the host to connect to.
  abstract final int streamingPort;

  Future<T> run();

  // Can't use factory functions since SSHRV contains a generic type
  static SSHRV localBinary(String host, int streamingPort) {
    return SSHRVImpl(host, streamingPort);
  }

  static SSHRV pureDart(String host, int streamingPort) {
    return SSHRVImplPureDart(host, streamingPort);
  }

  static Future<SSHRV> preferLocalBinary(String host, int streamingPort) async {
    String? localBinaryPath = await getLocalBinaryPath();
    if (localBinaryPath != null) {
      return localBinary(host, streamingPort);
    }
    return pureDart(host, streamingPort);
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
