import 'dart:convert';
import 'dart:math';

import 'package:at_client/at_client.dart';
import 'package:noports_core/events.dart';
import 'package:at_utils/at_logger.dart';

final GetRequestOptions _gro = GetRequestOptions()..useRemoteAtServer = true;
final PutRequestOptions _pro = PutRequestOptions()..useRemoteAtServer = true;

mixin AtEventListener {
  AtClient get atClient;

  Atsign get myAtsign => atClient.getCurrentAtSign()!;

  AtSignLogger get logger;

  Future<AtEventLoggingConfig> _getConfig(AtKey key) async {
    logger.shout('Fetching EventLoggingConfig from $key');
    AtValue v = await atClient.get(key, getRequestOptions: _gro);
    final elc = AtEventLoggingConfig.fromJson(jsonDecode(v.value));
    logger.shout('Fetched EventLoggingConfig $elc');
    return elc;
  }

  /// namespace like `events.logging.sshnp` will result in the config being
  /// stored at `config.events.logging.sshnp`, and an EventLoggingConfig with a
  /// topic something like `abc123def4.events.logging.sshnp`
  Future<AtEventLoggingConfig> getOrCreateConfig({
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
      final elc = AtEventLoggingConfig(
        atSign: myAtsign,
        topic: '${_generateRandomString(8)}.$namespace',
        ttln: ttln,
      );
      logger.shout('Creating new EventLoggingConfig at $configKey');
      await atClient.put(
        configKey,
        jsonEncode(elc.toJson()),
        putRequestOptions: _pro,
      );
      logger.shout('Created new EventLoggingConfig $elc');
      return elc;
    } catch (err) {
      if (err.toString().toLowerCase().contains('immutable')) {
        logger.shout(
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
    required AtEventLoggingConfig config,
    required List<Atsign> atSigns,
    required String namespace,
  }) async {
    for (final theirAtsign in atSigns) {
      logger.shout('Sharing EventLoggingConfig $config with $theirAtsign');
      AtKey key = AtKey.fromString('$theirAtsign:config.$namespace$myAtsign');
      await atClient.put(
        key,
        jsonEncode(config.toJson()),
        putRequestOptions: _pro,
      );
    }
  }
}

mixin AtEventLogger {
  AtClient get atClient;

  Atsign get myAtsign => atClient.getCurrentAtSign()!;

  AtSignLogger get logger;

  static Future<AtEventLoggingConfig> staticGetEventLoggingConfig({
    required AtClient atClient,
    required Atsign atSign,
    required String namespace,
  }) async {
    Atsign myAtsign = atClient.getCurrentAtSign()!.toAtsign();
    AtKey key = AtKey.fromString('$myAtsign:config.$namespace$atSign');
    AtValue v = await atClient.get(key, getRequestOptions: _gro);
    return AtEventLoggingConfig.fromJson(jsonDecode(v.value));
  }

  /// atSign `@alice` and namespace `events.logging.sshnp` will result in the
  /// config being fetched from `@bob:config.events.logging.sshnp@alice`
  Future<AtEventLoggingConfig> getEventLoggingConfigFrom({
    required Atsign atSign,
    required String namespace,
  }) async {
    return await staticGetEventLoggingConfig(
      atClient: atClient,
      atSign: atSign,
      namespace: namespace,
    );
  }

  Future<void> logEvent(AtEventLoggingConfig config, Map<String, dynamic> json) async {
    logger.shout(
      'Sending log to ${config.atSign} on ${config.topic}: $json',
    );
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey.fromString(
          '${config.atSign}:${config.topic}${atClient.getCurrentAtSign()!}',
        )..metadata.namespaceAware = false,
        value: jsonEncode(json),
        notificationExpiry: Duration(milliseconds: config.ttln),
      ),
      waitForFinalDeliveryStatus: false,
      checkForFinalDeliveryStatus: false,
    );
  }
}

final random = Random();

String _generateRandomString(int length) {
  const charset =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return List.generate(
    length,
    (_) => charset[random.nextInt(charset.length)],
  ).join();
}
