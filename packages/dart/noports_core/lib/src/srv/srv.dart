import 'dart:io';

import 'package:dartssh2/dartssh2.dart';
import 'package:noports_core/src/srv/relay_authenticators.dart';
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

  abstract final RelayAuthenticator? relayAuthenticator;

  /// The AES key for Client-to-Daemon encryption in a single-socket
  /// session, or on the control channel for a multi-socket session
  abstract final String? aesC2D;

  /// The IV to use with the [aesC2D]
  abstract final String? ivC2D;

  /// The AES key for Daemon-to-Client encryption in a single-socket
  /// session, or on the control channel for a multi-socket session
  abstract final String? aesD2C;

  /// The IV to use with the [aesD2C]
  abstract final String? ivD2C;

  /// Whether to bind a local port or not
  abstract final bool? bindLocalPort;

  /// Whether to enable multiple connections or not
  abstract final bool multi;

  /// How long to keep the SocketConnector open if there have been no connections
  abstract final Duration timeout;

  /// How frequently to send heartbeats over the control channel.
  ///
  /// Heartbeats are an attempt to persuade over-zealous network
  /// intermediaries that the control channel shouldn't be closed due to lack
  /// of activity.
  abstract final Duration? controlChannelHeartbeat;

  Future<T> run();

  // Can't use factory functions since Srv contains a generic type
  static Srv<Process> exec(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    String? localHost,
    bool? bindLocalPort,
    String? rvdAuthString,
    required RelayAuthenticator? relayAuthenticator,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  }) {
    return SrvImplExec(
      streamingHost,
      streamingPort,
      localPort: localPort,
      localHost: localHost,
      bindLocalPort: bindLocalPort,
      relayAuthenticator: relayAuthenticator,
      aesC2D: aesC2D,
      ivC2D: ivC2D,
      aesD2C: aesD2C,
      ivD2C: ivD2C,
      multi: multi,
      timeout: timeout,
      controlChannelHeartbeat: controlChannelHeartbeat,
    );
  }

  static Srv<SocketConnector> dart(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    bool? bindLocalPort,
    String? localHost,
    String? rvdAuthString,
    required RelayAuthenticator? relayAuthenticator,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  }) {
    return SrvImplDart(
      streamingHost,
      streamingPort,
      localPort: localPort!,
      localHost: localHost,
      bindLocalPort: bindLocalPort!,
      relayAuthenticator: relayAuthenticator,
      aesC2D: aesC2D,
      ivC2D: ivC2D,
      aesD2C: aesD2C,
      ivD2C: ivD2C,
      multi: multi,
      detached: detached,
      timeout: timeout,
      controlChannelHeartbeat: controlChannelHeartbeat,
    );
  }

  static Srv<SSHSocket> inline(
    String streamingHost,
    int streamingPort, {
    int? localPort,
    bool? bindLocalPort,
    String? localHost,
    String? rvdAuthString,
    required RelayAuthenticator? relayAuthenticator,
    String? aesC2D,
    String? ivC2D,
    String? aesD2C,
    String? ivD2C,
    bool multi = false,
    bool detached = false,
    Duration timeout = DefaultArgs.srvTimeout,
    Duration? controlChannelHeartbeat,
  }) {
    return SrvImplInline(
      streamingHost,
      streamingPort,
      relayAuthenticator: relayAuthenticator,
      aesC2D: aesC2D,
      ivC2D: ivC2D,
      aesD2C: aesD2C,
      ivD2C: ivD2C,
      multi: multi,
      timeout: timeout,
      controlChannelHeartbeat: controlChannelHeartbeat,
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
    List<String> pathList = Platform.resolvedExecutable.split(
      Platform.pathSeparator,
    );
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
