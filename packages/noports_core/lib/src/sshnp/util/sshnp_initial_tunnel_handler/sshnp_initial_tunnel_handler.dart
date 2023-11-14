import 'dart:async';
import 'package:meta/meta.dart';

mixin SshnpInitialTunnelHandler<T> {
  @protected
  Future<T> startInitialTunnel({required String identifier});
}
