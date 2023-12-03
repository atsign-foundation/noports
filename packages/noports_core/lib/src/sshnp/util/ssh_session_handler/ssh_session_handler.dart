import 'dart:async';
import 'package:meta/meta.dart';

mixin SshSessionHandler<T> {
  @protected
  @visibleForTesting
  Future<T> startInitialTunnelSession({required String keyPairIdentifier});

  @protected
  @visibleForTesting
  Future<T> startUserSession({required T tunnelSession});
}
