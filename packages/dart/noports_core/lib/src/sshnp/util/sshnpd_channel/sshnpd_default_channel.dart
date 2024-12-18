import 'dart:async';
import 'dart:convert';

import 'package:at_chops/at_chops.dart';
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
    bool validResponse = notification.value?.startsWith('{') ?? false;
    if (!validResponse) {
      logger.shout('invalid daemon response: ${notification.value}');
      return SshnpdAck.acknowledgedWithErrors;
    } else {
      late final Map envelope;
      late final Map daemonResponse;
      try {
        envelope = jsonDecode(notification.value!);
        assertValidMapValue(envelope, 'signature', String);
        assertValidMapValue(envelope, 'hashingAlgo', String);
        assertValidMapValue(envelope, 'signingAlgo', String);

        daemonResponse = envelope['payload'] as Map;
        assertValidMapValue(daemonResponse, 'sessionId', String);
      } catch (e) {
        logger.shout(
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

      String? sessionAESKeyStringEncrypted = daemonResponse['sessionAESKey'];
      logger.info(
          'Received encrypted sessionAESKey: $sessionAESKeyStringEncrypted');

      String? sessionIVStringEncrypted = daemonResponse['sessionIV'];
      logger.info('Received encrypted sessionIV: $sessionIVStringEncrypted');

      if (sessionAESKeyStringEncrypted != null &&
          sessionIVStringEncrypted != null) {
        AtChops atChops =
            AtChopsImpl(AtChopsKeys.create(params.sessionKP, null));
        sessionAESKeyString = atChops
            .decryptString(sessionAESKeyStringEncrypted, params.sessionKPType)
            .result;
        sessionIVString = atChops
            .decryptString(sessionIVStringEncrypted, params.sessionKPType)
            .result;
      }

      return SshnpdAck.acknowledged;
    }
  }
}
