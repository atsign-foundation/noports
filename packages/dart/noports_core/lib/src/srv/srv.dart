import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/srv/srv_impl.dart';
import 'package:noports_core/utils.dart';
import 'package:socket_connector/socket_connector.dart';

abstract class Srv<T> {
  static const completedWithExceptionString = 'Exception running srv';

  static const startedString = 'rv started successfully';

  /// The internet address of the host to connect to.
  abstract final String streamingHost;

  /// The port of the host to connect to.
  abstract final int streamingPort;

  /// The local port to bridge to
  /// Defaults to 22
  abstract final int? localPort;

  /// The local host to bridge to
  /// Defaults to localhost
  abstract final String? localHost;

  /// A string which needs to be presented to the rvd before the rvd
  /// will allow any further traffic on the socket
  abstract final String? rvdAuthString;

  /// The AES key for encryption / decryption of the rv traffic
  abstract final String? sessionAESKeyString;

  /// The IV to use with the [sessionAESKeyString]
  abstract final String? sessionIVString;

  /// Whether to bind a local port or not
  abstract final bool? bindLocalPort;

  /// Whether to enable multiple connections or not
  abstract final bool multi;

  /// How long to keep the SocketConnector open if there have been no connections
  abstract final Duration timeout;

  Future<T> run();

  // Can't use factory functions since Srv contains a generic type
  static Srv<Process> exec(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    String? localHost,
    bool? bindLocalPort,
    String? rvdAuthString,
    String? sessionAESKeyString,
    String? sessionIVString,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
  }) {
    return SrvImplExec(
      streamingHost,
      streamingPort,
      localPort: localPort,
      localHost: localHost,
      bindLocalPort: bindLocalPort,
      rvdAuthString: rvdAuthString,
      sessionAESKeyString: sessionAESKeyString,
      sessionIVString: sessionIVString,
      multi: multi,
      timeout: timeout,
    );
  }

  static Srv<SocketConnector> dart(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    bool? bindLocalPort,
    String? localHost,
    String? rvdAuthString,
    String? sessionAESKeyString,
    String? sessionIVString,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
  }) {
    return SrvImplDart(
      streamingHost,
      streamingPort,
      localPort: localPort!,
      localHost: localHost,
      bindLocalPort: bindLocalPort!,
      rvdAuthString: rvdAuthString,
      sessionAESKeyString: sessionAESKeyString,
      sessionIVString: sessionIVString,
      multi: multi,
      detached: detached,
      timeout: timeout,
    );
  }

  static Srv<SSHSocket> inline(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    bool? bindLocalPort,
    String? localHost,
    String? rvdAuthString,
    String? sessionAESKeyString,
    String? sessionIVString,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
  }) {
    return SrvImplInline(
      streamingHost,
      streamingPort,
      rvdAuthString: rvdAuthString,
      sessionAESKeyString: sessionAESKeyString,
      sessionIVString: sessionIVString,
      multi: multi,
      timeout: timeout,
    );
  }

  static Future<String?> getLocalBinaryPath() async {
    List<String> binaryNames = ['srv', 'sshrv'];
    for (var name in binaryNames) {
      var binary = await _getBinaryPathByName(name);
      if (binary != null) return binary;
    }
    return null;
  }

  static Future<String?> _getBinaryPathByName(String name) async {
    String postfix = Platform.isWindows ? '.exe' : '';
    List<String> pathList =
        Platform.resolvedExecutable.split(Platform.pathSeparator);
    bool isExe = (pathList.last == 'sshnp$postfix' ||
        pathList.last == 'sshnpd$postfix' ||
        pathList.last == 'npt$postfix');

    pathList
      ..removeLast()
      ..add('$name$postfix');

    File binaryName = File(pathList.join(Platform.pathSeparator));
    bool binaryExists = await binaryName.exists();
    return (isExe && binaryExists) ? binaryName.absolute.path : null;
  }
}
