import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/sshnp/mixins/sshnp_ssh_key_handler.dart';
import 'package:noports_core/sshnp_impl.dart';
import 'package:noports_core/utils.dart';

mixin DefaultSSHNPDPayloadHandler on SSHNPCore {
  @protected
  late String ephemeralPrivateKey;

  @protected
  bool get useLocalFileStorage => (this is SSHNPLocalSSHKeyHandler);

  @override
  FutureOr<bool> handleSshnpdPayload(AtNotification notification) async {
    logger.info(
        'Received notification from $sshnpdAtSign: ${notification.key} - ${notification.value}');
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
        sshnpdAck = true;
        sshnpdAckErrors = true;
        return false;
      }

      try {
        await verifyEnvelopeSignature(atClient, sshnpdAtSign, logger, envelope,
            useFileStorage: useLocalFileStorage);
      } catch (e) {
        logger.shout('Failed to verify signature of msg from $sshnpdAtSign');
        logger.shout('Exception: $e');
        logger.shout('Notification value: ${notification.value}');
        sshnpdAck = true;
        sshnpdAckErrors = true;
        return false;
      }

      logger.info('Verified signature of msg from $sshnpdAtSign');
      logger.info('Setting ephemeralPrivateKey');
      ephemeralPrivateKey = daemonResponse['ephemeralPrivateKey'];
      return true;
    }
    return false;
  }
}

mixin LegacySSHNPDPayloadHandler on SSHNPCore {
  @override
  bool handleSshnpdPayload(AtNotification notification) {
    return (notification.value == 'connected');
  }
}
