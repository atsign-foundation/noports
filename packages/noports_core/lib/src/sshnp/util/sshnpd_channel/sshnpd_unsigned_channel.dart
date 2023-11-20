import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';

class SshnpdUnsignedChannel extends SshnpdChannel
    with SshnpdUnsignedPayloadHandler {
  SshnpdUnsignedChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.namespace,
  });
}

mixin SshnpdUnsignedPayloadHandler on SshnpdChannel {
  @override
  Future<void> initialize() async {
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpdAck> handleSshnpdPayload(AtNotification notification) async {
    return (notification.value == 'connected')
        ? SshnpdAck.acknowledged
        : SshnpdAck.acknowledgedWithErrors;
  }
}
