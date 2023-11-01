import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/channels/sshnpd/sshnpd_channel.dart';

class SshnpdVersion3Channel extends SshnpdChannel
    with SshnpdVersion3PayloadHandler {
  SshnpdVersion3Channel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.namespace,
  });
}

abstract mixin class SshnpdVersion3PayloadHandler implements SshnpdChannel {
  @override
  Future<bool> handleSshnpdPayload(AtNotification notification) async {
    return (notification.value == 'connected');
  }
}
