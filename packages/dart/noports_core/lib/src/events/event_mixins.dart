import 'dart:convert';
import 'dart:math';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/events/event_models.dart';

final GetRequestOptions _gro = GetRequestOptions()..useRemoteAtServer = true;
final PutRequestOptions _pro = PutRequestOptions()..useRemoteAtServer = true;

mixin AtEventListener {
  AtClient get atClient;

  Atsign get myAtsign => atClient.getCurrentAtSign()!;

  AtSignLogger get logger;

  Future<AtEventLoggingConfig> _getConfig(AtKey key) async {
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
    Duration ttln = const Duration(hours: 1),
  }) async {
    final configKey = AtKey.fromString('config.$namespace$myAtsign')
      ..metadata.namespaceAware = false
      ..metadata.immutable = true;

    try {
      return await _getConfig(configKey);
    } catch (e) {
      if (e is! KeyNotFoundException) {
        rethrow;
      }
    }

    try {
      final elc = AtEventLoggingConfig(
        atSign: myAtsign,
        topic: '${_generateRandomString(8)}.$namespace',
      );
      await atClient.put(configKey, elc, putRequestOptions: _pro);
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
      AtKey key = AtKey.fromString('$theirAtsign:config.$namespace$myAtsign')
        ..metadata.namespaceAware = false;
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
    AtKey key = AtKey.fromString('$myAtsign:config.$namespace:$atSign')
      ..metadata.namespaceAware = false;
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

  Future<void> logEvent(AtEventLoggingConfig config, AtEvent event) async {
    logger.shout(
      'Sending log to ${config.atSign}: ${event.toJson().toString()}',
    );
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey.fromString(
          '${config.atSign}:${config.topic}${atClient.getCurrentAtSign()!}',
        )..metadata.namespaceAware = false,
        value: jsonEncode(event.toJson()),
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
