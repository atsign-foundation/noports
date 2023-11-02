import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshnp/util/sshnp_ssh_key_handler.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import 'package:noports_core/utils.dart';

class SshnpdDefaultChannel extends SshnpdChannel
    with SshnpdDefaultPayloadHandler {
  SshnpdDefaultChannel({
    required super.atClient,
    required super.params,
    required super.sessionId,
    required super.namespace,
  });
}

mixin SshnpdDefaultPayloadHandler on SshnpdChannel {
  late final String ephemeralPrivateKey;

  @protected
  bool get useLocalFileStorage => (this is SshnpLocalSshKeyHandler);

  @override
  Future<void> initialize() async {
    await super.initialize();
    completeInitialization();
  }

  @override
  Future<SshnpdAck> handleSshnpdPayload(AtNotification notification) async {
    if (notification.value?.startsWith('{') ?? false) {
      late final Map envelope;
      late final Map daemonResponse;
      try {
        envelope = jsonDecode(notification.value!);
        assertValidValue(envelope, 'signature', String);
        assertValidValue(envelope, 'hashingAlgo', String);
        assertValidValue(envelope, 'signingAlgo', String);

        daemonResponse = envelope['payload'] as Map;
        assertValidValue(daemonResponse, 'sessionId', String);
        assertValidValue(daemonResponse, 'ephemeralPrivateKey', String);
      } catch (e) {
        logger.warning(
            'Failed to extract parameters from notification value "${notification.value}" with error : $e');
        return SshnpdAck.acknowledgedWithErrors;
      }

      try {
        await verifyEnvelopeSignature(
          atClient,
          params.sshnpdAtSign,
          logger,
          envelope,
          useFileStorage: useLocalFileStorage,
        );
      } catch (e) {
        logger.shout(
            'Failed to verify signature of msg from ${params.sshnpdAtSign}');
        logger.shout('Exception: $e');
        logger.shout('Notification value: ${notification.value}');
        return SshnpdAck.acknowledgedWithErrors;
      }

      logger.info('Verified signature of msg from ${params.sshnpdAtSign}');
      logger.info('Setting ephemeralPrivateKey');
      ephemeralPrivateKey = daemonResponse['ephemeralPrivateKey'];
      return SshnpdAck.acknowledged;
    }
    return SshnpdAck.acknowledgedWithErrors;
  }
}
