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
  String? aesC2D;
  String? ivC2D;
  String? aesD2C;
  String? ivD2C;
  String? errorReceived;

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
      errorReceived = notification.value;
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
          'Failed to extract parameters from notification value "${notification.value}" with error : $e',
        );
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
          'Failed to verify signature of msg from ${params.sshnpdAtSign}',
        );
        logger.shout('Exception: $e');
        logger.shout('Notification value: ${notification.value}');
        return SshnpdAck.acknowledgedWithErrors;
      }

      logger.info('Verified signature of msg from ${params.sshnpdAtSign}');

      ephemeralPrivateKey = daemonResponse['ephemeralPrivateKey'];
      logger.info('Received ephemeralPrivateKey: $ephemeralPrivateKey');

      AtChops? atChops;

      String? aesKeyC2DEncrypted =
          daemonResponse['sessionAESKey'] ?? daemonResponse['aesKeyC2D'];
      logger.info('Received encrypted aesKeyC2D: $aesKeyC2DEncrypted');

      String? ivC2DEncrypted =
          daemonResponse['sessionIV'] ?? daemonResponse['ivC2D'];
      logger.info('Received encrypted ivC2D: $ivC2DEncrypted');

      if (aesKeyC2DEncrypted != null && ivC2DEncrypted != null) {
        atChops ??= AtChopsImpl(AtChopsKeys.create(params.sessionKP, null));
        aesC2D = atChops
            .decryptString(aesKeyC2DEncrypted, params.sessionKPType)
            .result;
        ivC2D =
            atChops.decryptString(ivC2DEncrypted, params.sessionKPType).result;
      }

      String? aesKeyD2CEncrypted = daemonResponse['aesKeyD2C'];
      logger.info('Received encrypted aesKeyD2C: $aesKeyD2CEncrypted');

      String? ivD2CEncrypted = daemonResponse['ivD2C'];
      logger.info('Received encrypted ivD2C: $ivD2CEncrypted');

      if (aesKeyD2CEncrypted != null && ivD2CEncrypted != null) {
        atChops ??= AtChopsImpl(AtChopsKeys.create(params.sessionKP, null));
        aesD2C = atChops
            .decryptString(aesKeyD2CEncrypted, params.sessionKPType)
            .result;
        ivD2C =
            atChops.decryptString(ivD2CEncrypted, params.sessionKPType).result;
      }

      return SshnpdAck.acknowledged;
    }
  }
}
