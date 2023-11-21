import 'dart:async';
import 'package:meta/meta.dart';

mixin SshnpInitialTunnelHandler<T> {
  @protected
  @visibleForTesting
  Future<T> startInitialTunnel({required String identifier});
}
