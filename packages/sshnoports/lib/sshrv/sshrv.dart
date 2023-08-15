import 'dart:io';

import 'package:meta/meta.dart';
import 'package:socket_connector/socket_connector.dart';

part 'sshrv_impl.dart';

abstract class SSHRV<T> {
  /// The internet address of the host to connect to.
  abstract final String host;

  /// The port of the host to connect to.
  abstract final int streamingPort;

  static SSHRV<ProcessResult> localBinary(String host, int streamingPort) {
    return SSHRVImpl(host, streamingPort);
  }

  static SSHRV<SocketConnector> pureDart(String host, int streamingPort) {
    return SSHRVImplPureDart(host, streamingPort);
  }

  Future<T> run();
}
