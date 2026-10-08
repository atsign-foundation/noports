import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:at_base2e15/at_base2e15.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/events.dart';
import 'package:archive/archive.dart';

final GetRequestOptions _gro = GetRequestOptions()..useRemoteAtServer = true;
final PutRequestOptions _pro = PutRequestOptions()..useRemoteAtServer = true;

mixin AtEventListener on AtClientBindings {
  Atsign get myAtsign => atClient.getCurrentAtSign()!.toAtsign();

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
      AtKey key = AtKey.fromString('$theirAtsign:config.$namespace$myAtsign')
        ..metadata.ttr = -1
        ..metadata.ccd = true;
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
      try {
        yield AtEventEnvelope.fromJson(jsonDecode(n.value!)).payload;
      } catch (e) {
        logger.shout('Failed to unmarshal event: $e');
      }
    }
  }
}

mixin AtEventLogger on AtClientBindings {
  Atsign get myAtsign => atClient.getCurrentAtSign()!.toAtsign();

  final StreamController<(AtEventConfig, AtEventEnvelope)>
  eventStreamController = StreamController<(AtEventConfig, AtEventEnvelope)>();
  bool eventLoggerRunning = false;

  /// [atSign] `@alice` and [namespace] `events.logging.sshnp` and our atSign
  /// being `@bob` will result in the config being fetched from
  /// `@bob:config.events.logging.sshnp@alice`
  Future<AtEventConfig> getEventLoggingConfig({
    required Atsign atSign,
    required String namespace,
  }) async {
    Atsign myAtsign = atClient.getCurrentAtSign()!.toAtsign();
    AtKey key = AtKey.fromString('$myAtsign:config.$namespace$atSign');
    AtValue v = await atClient.get(key, getRequestOptions: _gro);
    return AtEventConfig.fromJson(jsonDecode(v.value));
  }

  Future<void> logEvent(
    AtEventConfig config,
    Map<String, dynamic> json, {
    CompressionScheme compressionScheme = CompressionScheme.zlib,
    EncodingScheme encodingScheme = EncodingScheme.base2e15,
  }) async {
    eventStreamController.add((
      config,
      AtEventEnvelope(
        payload: jsonEncode(json),
        compressionScheme: compressionScheme,
        encodingScheme: encodingScheme,
      ),
    ));
    if (!eventLoggerRunning) {
      startEventLogger();
    }
  }

  void startEventLogger() async {
    eventLoggerRunning = true;
    await for (final tuple in eventStreamController.stream) {
      final AtEventConfig config = tuple.$1;
      final AtEventEnvelope envelope = tuple.$2;

      try {
        logger.finer(
          'Sending log to ${config.atSign} on ${config.topic}: ${envelope.payload}',
        );
        logger.info(
          'bytes: json: ${envelope.payload.length},'
          ' compressed and encoded: ${envelope.encodedCompressed.length}',
        );
        await notify(
          AtKey.fromString(
            '${config.atSign}:${config.topic}${atClient.getCurrentAtSign()!}',
          )..metadata.namespaceAware = false,
          jsonEncode(envelope.toJson()),
          ttln: Duration(milliseconds: config.ttln),
          waitForFinalDeliveryStatus: false,
          checkForFinalDeliveryStatus: false,
        );
      } catch (e) {
        logger.severe('Error while sending ${envelope.payload} to $config');
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

class AtEventEnvelope {
  static final ZLibEncoder zlibEncoder = ZLibEncoder();
  static final ZLibDecoder zlibDecoder = ZLibDecoder();
  final String payload;
  final CompressionScheme compressionScheme;
  final EncodingScheme encodingScheme;

  AtEventEnvelope({
    required this.payload,
    required this.compressionScheme,
    required this.encodingScheme,
  });

  Map<String, dynamic> get atEventPayload => jsonDecode(payload);

  List<int>? _compressed;

  List<int> get compressed {
    if (_compressed != null) {
      return _compressed!;
    }
    switch (compressionScheme) {
      case CompressionScheme.zlib:
        return _compressed = zlibEncoder.encodeBytes(payload.codeUnits);
      case CompressionScheme.none:
        return _compressed = payload.codeUnits;
    }
  }

  String? _encodedCompressed;

  String get encodedCompressed {
    if (_encodedCompressed != null) {
      return _encodedCompressed!;
    }
    switch (encodingScheme) {
      case EncodingScheme.base2e15:
        return _encodedCompressed = Base2e15.encode(compressed);
      case EncodingScheme.base64:
        return _encodedCompressed = base64Encode(compressed);
    }
  }

  static List<int> decode({
    required String encodedCompressedPayload,
    required String encodingSchemeName,
  }) {
    final EncodingScheme encodingScheme;
    try {
      encodingScheme = EncodingScheme.values.byName(encodingSchemeName);
    } catch (e) {
      throw UnimplementedError(
        'Cannot decode - unknown encodingScheme "$encodingSchemeName"',
      );
    }
    switch (encodingScheme) {
      case EncodingScheme.base2e15:
        return Base2e15.decode(encodedCompressedPayload);
      case EncodingScheme.base64:
        return base64Decode(encodedCompressedPayload);
    }
  }

  static String decompress({
    required List<int> compressedPayload,
    required String compressionSchemeName,
  }) {
    final CompressionScheme compressionScheme;
    try {
      compressionScheme = CompressionScheme.values.byName(
        compressionSchemeName,
      );
    } catch (e) {
      throw UnimplementedError(
        'Unknown compressionScheme "$compressionSchemeName"',
      );
    }
    switch (compressionScheme) {
      case CompressionScheme.zlib:
        return String.fromCharCodes(zlibDecoder.decodeBytes(compressedPayload));
      case CompressionScheme.none:
        return String.fromCharCodes(compressedPayload);
    }
  }

  Map<String, dynamic> toJson() => {
    'cs': compressionScheme.name,
    'es': encodingScheme.name,
    'ecp': encodedCompressed,
  };

  factory AtEventEnvelope.fromJson(Map<String, dynamic> json) {
    String stringFromJson(String k) {
      try {
        return json[k] as String;
      } catch (e) {
        throw ArgumentError('Invalid event payload value for $k');
      }
    }

    final String compressionSchemeName = stringFromJson('cs');
    final String encodingSchemeName = stringFromJson('es');
    final String encodedCompressedPayload = stringFromJson('ecp');

    return AtEventEnvelope(
      payload: decompress(
        compressedPayload: decode(
          encodedCompressedPayload: encodedCompressedPayload,
          encodingSchemeName: encodingSchemeName,
        ),
        compressionSchemeName: compressionSchemeName,
      ),
      compressionScheme: CompressionScheme.values.byName(compressionSchemeName),
      encodingScheme: EncodingScheme.values.byName(encodingSchemeName),
    );
  }
}

enum CompressionScheme { none, zlib }

enum EncodingScheme { base64, base2e15 }
