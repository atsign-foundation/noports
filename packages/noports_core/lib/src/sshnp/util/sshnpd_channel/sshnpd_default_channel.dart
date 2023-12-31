import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';

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
  String? ephemeralPrivateKey;
  String? sessionAESKeyString;
  String? sessionIVString;

  @visibleForTesting
  // disable publickey cache on windows
  FileSystem? fs = Platform.isWindows ? null : LocalFileSystem();

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
          fs: fs,
        );
      } catch (e) {
        logger.shout(
            'Failed to verify signature of msg from ${params.sshnpdAtSign}');
        logger.shout('Exception: $e');
        logger.shout('Notification value: ${notification.value}');
        return SshnpdAck.acknowledgedWithErrors;
      }

      logger.info('Verified signature of msg from ${params.sshnpdAtSign}');

      ephemeralPrivateKey = daemonResponse['ephemeralPrivateKey'];
      logger.info('Received ephemeralPrivateKey: $ephemeralPrivateKey');

      sessionAESKeyString = daemonResponse['sessionAESKey'];
      logger.info('Received sessionAESKey: $sessionAESKeyString');

      sessionIVString = daemonResponse['sessionIV'];
      logger.info('Received sessionIV: $sessionIVString');

      return SshnpdAck.acknowledged;
    }
    return SshnpdAck.acknowledgedWithErrors;
  }
}
