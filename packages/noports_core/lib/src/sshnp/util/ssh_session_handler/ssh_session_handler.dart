import 'dart:async';
import 'package:meta/meta.dart';

mixin SshSessionHandler<T> {
  @protected
  @visibleForTesting
  Future<T> startInitialTunnelSession(
      {required String ephemeralKeyPairIdentifier, int? localRvPort});

  @protected
  @visibleForTesting
  Future<T> startUserSession({
    required T tunnelSession,
  });
}
