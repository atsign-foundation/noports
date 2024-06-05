import 'dart:async';
import 'package:dartssh2/dartssh2.dart';
import 'package:meta/meta.dart';

mixin SshSessionHandler<T> {
  @protected
  @visibleForTesting
  Future<T> startInitialTunnelSession({
    required String ephemeralKeyPairIdentifier,
    int? localRvPort,
    SSHSocket? sshSocket,
  });

  @protected
  @visibleForTesting
  Future<T> startUserSession();
}
