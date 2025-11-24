import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:at_base2e15/at_base2e15.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:shrink/core/core.dart';

final GetRequestOptions _gro = GetRequestOptions()..useRemoteAtServer = true;
final PutRequestOptions _pro = PutRequestOptions()..useRemoteAtServer = true;

mixin AtEventListener on AtClientBindings {
  Atsign get myAtsign => atClient.getCurrentAtSign()!;

  Future<AtEventConfig> _getConfig(AtKey key) async {
    logger.info('Fetching EventLoggingConfig from $key');
    AtValue v = await atClient.get(key, getRequestOptions: _gro);
    final elc = AtEventConfig.fromJson(jsonDecode(v.value));
    logger.info('Fetched EventLoggingConfig $elc');
    return elc;
  }

  /// namespace like `events.logging.sshnp` will result in the config being
  /// stored at `config.events.logging.sshnp`, and an EventLoggingConfig with a
  /// topic something like `abc123def4.events.logging.sshnp`
  Future<AtEventConfig> getOrCreateConfig({
    required String namespace,
    required int ttln,
  }) async {
    final configKey = AtKey.fromString('config.$namespace$myAtsign')
      ..metadata.immutable = true;

    try {
      return await _getConfig(configKey);
    } catch (e) {
      if (e is! AtKeyNotFoundException) {
        rethrow;
      }
    }

    try {
      final elc = AtEventConfig(
        atSign: myAtsign,
        topic: '${_generateRandomString(8)}.$namespace',
        ttln: ttln,
      );
      logger.info('Creating new EventLoggingConfig at $configKey');
      await atClient.put(
        configKey,
        jsonEncode(elc.toJson()),
        putRequestOptions: _pro,
      );
      logger.info('Created new EventLoggingConfig $elc');
      return elc;
    } catch (err) {
      if (err.toString().toLowerCase().contains('immutable')) {
        logger.info(
          'EventLoggingConfig has been created by another program - will try to fetch again',
        );
        return await _getConfig(configKey);
      } else {
        rethrow;
      }
    }
  }

  /// namespace like `events.logging.sshnp` will result in the config being
  /// shared as `@bob:config.events.logging.sshnp@alice` etc
  Future<void> shareEventLoggingConfigWithAtsigns({
    required AtEventConfig config,
    required List<Atsign> atSigns,
    required String namespace,
  }) async {
    for (final theirAtsign in atSigns) {
      logger.info('Sharing EventLoggingConfig $config with $theirAtsign');
      AtKey key = AtKey.fromString('$theirAtsign:config.$namespace$myAtsign');
      await atClient.put(
        key,
        jsonEncode(config.toJson()),
        putRequestOptions: _pro,
      );
    }
  }

  Stream<String> getJsonStream(AtEventConfig elc) async* {
    logger.info('Subscribing to ${elc.topicListenRegex}');
    Stream<AtNotification> stream = subscribe(
      regex: elc.topicListenRegex.toLowerCase(),
      shouldDecrypt: true,
    );
    await for (final n in stream) {
      if (n.value == null) {
        continue;
      }
      String base2e15EncodedShrunkJson = n.value!;
      Uint8List shrunkJson = Base2e15.decode(base2e15EncodedShrunkJson);
      String jsonEncoded = Restore.text(shrunkJson);
      logger.info(
        'bytes: json: ${jsonEncoded.length},'
        ' base2e15EncodedShrunkJson: ${base2e15EncodedShrunkJson.length}',
      );
      yield jsonEncoded;
    }
  }
}

typedef AtEvent = Map<String, dynamic>;
mixin AtEventLogger on AtClientBindings {
  Atsign get myAtsign => atClient.getCurrentAtSign()!;

  final StreamController<(AtEventConfig, AtEvent)> eventStreamController =
      StreamController<(AtEventConfig, AtEvent)>();
  bool eventLoggerRunning = false;

  static Future<AtEventConfig> staticGetEventLoggingConfig({
    required AtClient atClient,
    required Atsign atSign,
    required String namespace,
  }) async {
    Atsign myAtsign = atClient.getCurrentAtSign()!.toAtsign();
    AtKey key = AtKey.fromString('$myAtsign:config.$namespace$atSign');
    AtValue v = await atClient.get(key, getRequestOptions: _gro);
    return AtEventConfig.fromJson(jsonDecode(v.value));
  }

  /// [atSign] `@alice` and [namespace] `events.logging.sshnp` and our atSign
  /// being `@bob` will result in the config being fetched from
  /// `@bob:config.events.logging.sshnp@alice`
  Future<AtEventConfig> getEventLoggingConfig({
    required Atsign atSign,
    required String namespace,
  }) async {
    return await staticGetEventLoggingConfig(
      atClient: atClient,
      atSign: atSign,
      namespace: namespace,
    );
  }

  Future<void> logEvent(AtEventConfig config, AtEvent json) async {
    eventStreamController.add((config, json));
    if (!eventLoggerRunning) {
      startEventLogger();
    }
  }

  void startEventLogger() async {
    eventLoggerRunning = true;
    await for (final tuple in eventStreamController.stream) {
      final AtEventConfig config = tuple.$1;
      final AtEvent json = tuple.$2;

      String jsonEncoded;
      try {
        jsonEncoded = jsonEncode(json);
      } catch (e) {
        logger.severe('Could not jsonEncode $json');
        continue;
      }

      try {
        logger.finer(
          'Sending log to ${config.atSign} on ${config.topic}: $jsonEncoded',
        );
        final shrunkJson = Shrink.text(jsonEncoded);
        String base2e15EncodedShrunkJson = Base2e15.encode(shrunkJson);
        logger.info(
          'bytes: json: ${jsonEncoded.length},'
          ' base2e15EncodedShrunkJson: ${base2e15EncodedShrunkJson.length}',
        );
        await notify(
          AtKey.fromString(
            '${config.atSign}:${config.topic}${atClient.getCurrentAtSign()!}',
          )..metadata.namespaceAware = false,
          base2e15EncodedShrunkJson,
          ttln: Duration(milliseconds: config.ttln),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false,
        );
      } catch (e) {
        logger.severe('Error while sending $jsonEncoded to $config');
      }
    }
  }
}

String _generateRandomString(int length) {
  const charset = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(
    length,
    (_) => charset[Random().nextInt(charset.length)],
  ).join().toLowerCase();
}
