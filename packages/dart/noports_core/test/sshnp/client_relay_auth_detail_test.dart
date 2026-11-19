import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:noports_core/src/common/features.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

import 'client_session_rig.dart';

/// A world with no live ping answer left from an earlier session.
ClientWorld newWorld() {
  SshnpdChannel.forgetLiveAnswers();
  return ClientWorld();
}

/// The daemon channel of a session from [client] to [daemon]'s [device].
SshnpdDefaultChannel channelIn(
  ClientWorld world, {
  String client = clientAtSign,
  String daemon = daemonAtSign,
  String device = deviceName,
  bool verbose = false,
}) => SshnpdDefaultChannel(
  atClient: world.atClient,
  params: NptParams(
    clientAtSign: client,
    sshnpdAtSign: daemon,
    srvdAtSign: relayAtSign,
    remoteHost: 'localhost',
    remotePort: 22,
    device: device,
    inline: true,
    timeout: const Duration(minutes: 1),
    verbose: verbose,
  ),
  sessionId: const Uuid().v4(),
  namespace: '$device.sshnp',
);

/// A daemon channel seen as a session, so the rig can answer its ping.
class _ChannelSession implements ClientDriver {
  _ChannelSession(this.channel);

  final SshnpdChannel channel;

  @override
  String get name => 'the daemon channel';

  @override
  String get sessionId => channel.sessionId;

  @override
  String get daemon => channel.params.sshnpdAtSign;

  @override
  String get device => channel.params.device;

  @override
  String get daemonRequestKey => 'no daemon request';

  @override
  Future<Object?> start() => throw UnimplementedError();
}

/// Pings [channel]'s daemon, which answers with [response].
Future<void> pingAnswered(
  ClientWorld world,
  SshnpdChannel channel,
  Map<String, dynamic> response,
) async {
  final check = channel.featureCheck([DaemonFeature.srAuth]);
  await world.answerPing(_ChannelSession(channel), response);
  await check;
}

class _CapturedLog implements LoggingHandler {
  final List<LogRecord> records = [];

  @override
  void call(LogRecord record) => records.add(record);

  /// The warnings logged that name [key].
  Iterable<String> warningsNaming(String key) => [
    for (final r in records)
      if (r.level == Level.WARNING && r.message.contains(key)) r.message,
  ];
}

/// Captures what every logger made from now on logs, until the test ends.
_CapturedLog _captureLog() {
  final captured = _CapturedLog();
  final previous = AtSignLogger.defaultLoggingHandler;
  AtSignLogger.defaultLoggingHandler = captured;
  addTearDown(() => AtSignLogger.defaultLoggingHandler = previous);
  return captured;
}

const DaemonRelayAuthSupport escrWithKey = DaemonRelayAuthSupport(
  supportsRamEscr: true,
  publicSigningKeyUri: daemonSigningKeyUri,
);

void main() {
  group(
    'A ping response says the daemon supports ESCR only when it says so',
    () {
      for (final (String response, Map<String, dynamic> ping, bool escr) in [
        ('no supportedFeatures', {}, false),
        (
          'supportedFeatures that is not a map',
          {
            'supportedFeatures': [DaemonFeature.supportsRamEscr.name],
          },
          false,
        ),
        ('features without supportsRamEscr', {'supportedFeatures': {}}, false),
        (
          'supportsRamEscr false',
          {
            'supportedFeatures': {DaemonFeature.supportsRamEscr.name: false},
          },
          false,
        ),
        (
          'supportsRamEscr as text',
          {
            'supportedFeatures': {DaemonFeature.supportsRamEscr.name: 'true'},
          },
          false,
        ),
        (
          'supportsRamEscr true',
          {
            'supportedFeatures': {DaemonFeature.supportsRamEscr.name: true},
          },
          true,
        ),
      ]) {
        test(response, () {
          expect(
            DaemonRelayAuthSupport.fromPingResponse(ping).supportsRamEscr,
            escr,
            reason: 'a daemon supports ESCR only when its ping says true',
          );
        });
      }

      test('a publicSigningKeyUri that is not text is not used', () {
        expect(
          DaemonRelayAuthSupport.fromPingResponse({
            'publicSigningKeyUri': 7,
          }).publicSigningKeyUri,
          isNull,
          reason: 'only a text URI is handed to the relay to prefetch',
        );
      });
    },
  );

  group('A ping record decodes only from its own shape', () {
    final String now = DateTime.now().toUtc().toIso8601String();
    for (final (String shape, Object? value) in [
      ('a value that is not JSON', 'not a ping record'),
      ('JSON that is not a map', '[]'),
      ('no value at all', null),
      (
        'supportsRamEscr as text',
        jsonEncode({
          'storedAt': now,
          'supportsRamEscr': 'true',
          'publicSigningKeyUri': null,
        }),
      ),
      (
        'storedAt that is not a time',
        jsonEncode({
          'storedAt': 'yesterday',
          'supportsRamEscr': true,
          'publicSigningKeyUri': null,
        }),
      ),
      (
        'no storedAt',
        jsonEncode({'supportsRamEscr': true, 'publicSigningKeyUri': null}),
      ),
      (
        'a publicSigningKeyUri that is not text',
        jsonEncode({
          'storedAt': now,
          'supportsRamEscr': true,
          'publicSigningKeyUri': 7,
        }),
      ),
    ]) {
      test(shape, () {
        expect(
          () => DaemonPingRecord.decode(value),
          throwsA(anything),
          reason: '$shape is not a ping record',
        );
      });
    }

    test('a record is stored with its time in UTC', () {
      final String encoded = DaemonPingRecord(
        storedAt: DateTime.now(),
        support: escrWithKey,
      ).encode();
      expect(
        (jsonDecode(encoded) as Map)['storedAt'],
        endsWith('Z'),
        reason: 'installations in other time zones read the same instant',
      );
    });

    test('a record decodes to what was encoded', () {
      final stored = DateTime.utc(2026, 11, 19, 12);
      final DaemonPingRecord decoded = DaemonPingRecord.decode(
        DaemonPingRecord(storedAt: stored, support: escrWithKey).encode(),
      );
      expect(decoded.storedAt, stored, reason: 'storedAt survives');
      expect(decoded.support, escrWithKey, reason: 'the answer survives');
    });
  });

  test(
    "the record's key names the daemon and the client in canonical form",
    () {
      final channel = channelIn(
        newWorld(),
        client: 'Al.ice',
        daemon: '@B.ob',
        device: 'dev',
      );
      expect(
        channel.pingRecordKey.toString(),
        'cached.ping.bob.dev.sshnp@alice',
        reason: 'Atsigns in the key are canonical, and the daemon has no @',
      );
    },
  );

  group('The live answer kept for the process is keyed by client, daemon and '
      'device together', () {
    for (final (String other, String client, String daemon, String device) in [
      ('another client Atsign', '@dave', daemonAtSign, deviceName),
      ('another daemon Atsign', clientAtSign, '@carol', deviceName),
      ('another device', clientAtSign, daemonAtSign, 'other_dev'),
    ]) {
      test('an answer for $other is not used', () async {
        final w = newWorld();
        await pingAnswered(
          w,
          channelIn(w, client: client, daemon: daemon, device: device),
          pingResponse(escr: true),
        );

        expect(
          await channelIn(w).knownRelayAuthSupport(),
          isNull,
          reason: 'an answer for $other decides nothing for this device',
        );
      });
    }

    test('an answer for the same client, daemon and device is used, whatever '
        'their Atsigns\' case', () async {
      final w = newWorld();
      await pingAnswered(
        w,
        channelIn(w, client: '@Alice', daemon: '@BOB'),
        pingResponse(escr: true),
      );

      expect(
        await channelIn(w).knownRelayAuthSupport(),
        escrWithKey,
        reason: 'the live answer is kept by canonical Atsigns',
      );
    });
  });

  test('a record read that never answers counts as a failed read once its wait '
      'is over', () async {
    final w = newWorld()..readHangs = true;
    final channel = channelIn(w)
      ..pingRecordTimeout = const Duration(milliseconds: 200);
    final watch = Stopwatch()..start();

    expect(
      await channel.knownRelayAuthSupport().timeout(
        const Duration(seconds: 5),
        onTimeout: () =>
            fail('the client was still reading after five seconds'),
      ),
      isNull,
      reason: 'a read that never answers gives no answer',
    );
    expect(
      watch.elapsed,
      lessThan(const Duration(seconds: 2)),
      reason: 'the client waits for the read no longer than its bound',
    );
    await pingAnswered(w, channel, pingResponse(escr: true));
    await channel.refreshPingRecord();
    expect(w.writes, isEmpty, reason: 'nothing is written after a failed read');
  });

  test(
    'a record write that never answers is given up once its wait is over',
    () async {
      final w = newWorld()..writeHangs = true;
      final channel = channelIn(w)
        ..pingRecordTimeout = const Duration(milliseconds: 200);
      await channel.knownRelayAuthSupport();
      await pingAnswered(w, channel, pingResponse(escr: true));

      await channel.refreshPingRecord().timeout(
        const Duration(seconds: 2),
        onTimeout: () =>
            fail('the client waits for the write no longer than its bound'),
      );
      expect(w.writes, hasLength(1), reason: 'the client tried to write');
    },
  );

  test(
    'a record that cannot be decoded is rewritten from the live ping',
    () async {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = 'not a ping record';
      final channel = channelIn(w);

      expect(
        await channel.knownRelayAuthSupport(),
        isNull,
        reason: 'a record that cannot be decoded gives no answer',
      );
      await pingAnswered(w, channel, pingResponse(escr: true));
      await channel.refreshPingRecord();

      expect(
        w.writes,
        hasLength(1),
        reason: 'the client rewrites a record that cannot be decoded',
      );
      expect(
        DaemonPingRecord.decode(w.records[pingRecordKeyOf()]).support,
        escrWithKey,
        reason: 'the live answer replaces a record that cannot be decoded',
      );
    },
  );

  group('A ping record the client cannot use or keep is logged at warning, '
      'naming the record', () {
    for (final (String what, void Function(ClientWorld) give, bool live) in [
      (
        'a read that fails',
        (ClientWorld w) =>
            w.readFailure = AtClientException.message('the read failed'),
        false,
      ),
      (
        'a value that cannot be decoded',
        (ClientWorld w) => w.records[pingRecordKeyOf()] = 'not a ping record',
        false,
      ),
      (
        'a write that fails',
        (ClientWorld w) =>
            w.writeFailure = AtClientException.message('the write failed'),
        true,
      ),
      (
        'a write the atServer does not make',
        (ClientWorld w) => w.writeAnswer = false,
        true,
      ),
    ]) {
      test(what, () async {
        final log = _captureLog();
        final w = newWorld();
        give(w);
        final channel = channelIn(w, verbose: true);

        await channel.knownRelayAuthSupport();
        if (live) {
          await pingAnswered(w, channel, pingResponse(escr: true));
          await channel.refreshPingRecord();
        }

        expect(
          log.warningsNaming(pingRecordKeyOf()),
          isNotEmpty,
          reason: '$what is logged at warning, naming the record',
        );
      });
    }
  });

  test('a write that fails leaves the session going on', () async {
    for (final make in clients) {
      final w = newWorld();
      w.writeFailure = AtClientException.message('the write failed');
      final c = make(w);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      await w.answerRelay(c);
      await w.daemonRequest(c);

      expect(w.writes, hasLength(1), reason: '${c.name} tried to write');
      await w.finish(c, outcome);
    }
  });

  test('a relay that applied relayAuthModes has each side use the mode named, '
      'even when it does not auto-detect', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: true);
      final relayPort = await RelayPortA.open();
      final c = make(w);
      final outcome = c.start();

      await w.answerRelay(
        c,
        applied: true,
        autoDetects: false,
        portA: relayPort.port,
      );
      await w.answerPing(c, pingResponse(escr: true));
      final daemonRequest = await w.daemonRequest(c);
      await w.acceptSession(c);
      await relayPort.connected;
      await Future.delayed(const Duration(milliseconds: 500));

      expect(
        daemonRequest['relayAuthMode'],
        'escr',
        reason: '${c.name} tells the daemon the side B mode the relay applied',
      );
      expect(
        relayPort.received.toString(),
        isEmpty,
        reason:
            '${c.name} waits for the challenge on its ESCR socket, '
            'sending no legacy envelope',
      );
      unawaited(outcome);
    }
  });

  test('a relay that neither applied relayAuthModes nor auto-detects is sent '
      'no auth_modes notification', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: true);
      final c = make(w);
      final outcome = c.start();

      await w.answerRelay(c, applied: false, autoDetects: false);
      await w.answerPing(c, pingResponse(escr: true));
      await w.daemonRequest(c);

      expect(
        w.authModesSentBy(c),
        isNull,
        reason: '${c.name} sends auth_modes only to a relay that auto-detects',
      );
      await w.finish(c, outcome);
    }
  });

  group('An sshnp that needs no daemon feature sends no ping', () {
    ClientDriver sshnpNeedingNoFeature(ClientWorld w) =>
        clients[1](w, authenticateDeviceToRvd: false, encryptRvdTraffic: false);

    test(
      'and with a record, names its mode for the daemon and writes none',
      () async {
        final w = newWorld();
        w.records[pingRecordKeyOf()] = pingRecord(escr: true);
        final c = sshnpNeedingNoFeature(w);
        final outcome = c.start();

        final request = await w.relayRequest(c);
        await w.answerRelay(c, applied: true);
        final Object? error = await outcome.timeout(
          const Duration(seconds: 20),
        );

        expect(w.sentTo('ping.'), isEmpty, reason: 'sshnp sent no ping');
        expect(
          (request['relayAuthModes'] as Map)['sideB'],
          'escr',
          reason: 'the record decides the daemon side',
        );
        expect(w.writes, isEmpty, reason: 'there is no live answer to write');
        expect(
          '$error',
          isNot(contains('changed since it was last seen')),
          reason: 'with no live answer nothing contradicts the record',
        );
      },
    );

    test('and with no record, names legacy for the daemon', () async {
      final w = newWorld();
      final c = sshnpNeedingNoFeature(w);
      final outcome = c.start();

      final request = await w.relayRequest(c);
      await w.answerRelay(c, applied: true);
      await outcome.timeout(const Duration(seconds: 20));

      expect(
        (request['relayAuthModes'] as Map)['sideB'],
        'payload',
        reason: 'with no answer at all the daemon is taken not to do ESCR',
      );
      expect(w.writes, isEmpty, reason: 'there is no live answer to write');
    });
  });
}
