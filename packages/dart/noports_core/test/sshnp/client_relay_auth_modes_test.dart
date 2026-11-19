/// Catalogue: features/sshnp/client_relay_auth_modes.feature
library;

import 'dart:async';
import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:noports_core/sshnp_foundation.dart';
import 'package:test/test.dart';

import 'client_session_rig.dart';

const Map<String, String> escrBoth = {'sideA': 'escr', 'sideB': 'escr'};
const Map<String, String> escrThenLegacy = {
  'sideA': 'escr',
  'sideB': 'payload',
};
const Map<String, String> legacyBoth = {'sideA': 'payload', 'sideB': 'payload'};

/// A world with no live ping answer left from an earlier session.
ClientWorld newWorld() {
  SshnpdChannel.forgetLiveAnswers();
  return ClientWorld();
}

/// The ping record [world] holds for this device, decoded.
DaemonPingRecord recordIn(ClientWorld world) =>
    DaemonPingRecord.decode(world.records[pingRecordKeyOf()]);

/// Whether the client sent request_ports only after the ping response was
/// delivered.
bool askedRelayAfterPing(ClientWorld world) {
  final int ping = world.log.indexOf('delivered ping response');
  final int request = world.log.indexWhere(
    (e) => e.startsWith('sent') && e.contains('request_ports'),
  );
  return ping >= 0 && request > ping;
}

/// Starts [client] and checks it asks the relay only once its daemon has
/// answered the ping with [response].
Future<void> expectRelayAskedOnlyAfterPing(
  ClientWorld world,
  ClientDriver client,
  Map<String, dynamic> response,
) async {
  await world.recordReadAndSettled(client);
  expect(
    world
        .sentTo('request_ports')
        .where((p) => p.value!.contains(client.sessionId)),
    isEmpty,
    reason: '${client.name} must not ask the relay before the ping returns',
  );
  await world.answerPing(client, response);
  await world.relayRequest(client);
}

void main() {
  test(
    'With no record, the client asks the relay only after the ping returns',
    () async {
      for (final make in clients) {
        final w = newWorld();
        final c = make(w);
        final outcome = c.start();

        await expectRelayAskedOnlyAfterPing(w, c, pingResponse(escr: true));
        final request = await w.relayRequest(c);

        expect(
          askedRelayAfterPing(w),
          isTrue,
          reason:
              '${c.name} sends request_ports after the ping response: '
              '${w.log}',
        );
        expect(
          request['relayAuthModes'],
          escrBoth,
          reason: '${c.name} names ESCR for both sides of an ESCR daemon',
        );
        await w.finish(c, outcome);
      }
    },
  );

  test(
    'With no record and no ping response, the client never asks the relay',
    () async {
      for (final make in clients) {
        final w = newWorld();
        final c = make(w, daemonPingTimeout: const Duration(milliseconds: 500));

        final Object? thrown = await c.start().timeout(
          const Duration(seconds: 10),
        );

        expect(
          thrown,
          isA<TimeoutException>().having(
            (e) => e.message,
            'message',
            'Daemon feature check timed out',
          ),
          reason: '${c.name} fails with the ping timeout',
        );
        expect(
          w.sentTo('ping.$deviceName'),
          isNotEmpty,
          reason: '${c.name} pinged the daemon',
        );
        expect(
          w.sentTo('request_ports'),
          isEmpty,
          reason: '${c.name} never asks the relay without the ping response',
        );
      }
    },
  );

  test(
    'With a record, the client asks the relay without waiting for the ping',
    () async {
      for (final make in clients) {
        final w = newWorld();
        w.records[pingRecordKeyOf()] = pingRecord(escr: true);
        final c = make(w);
        final outcome = c.start();

        final request = await w.relayRequest(c);

        expect(
          w.log,
          isNot(contains('delivered ping response')),
          reason: '${c.name} asks the relay before the ping response arrives',
        );
        expect(
          request['relayAuthModes'],
          escrBoth,
          reason: '${c.name} names ESCR for both sides, as the record says',
        );
        expect(
          w.reads.single.useRemoteAtServer,
          isTrue,
          reason: "${c.name} reads the record from the client's own atServer",
        );

        await w.answerPing(c, pingResponse(escr: true));
        await w.answerRelay(c);
        await w.daemonRequest(c);
        await w.finish(c, outcome);
      }
    },
  );

  test(
    'The record\'s signing key URI still tells the relay what to prefetch',
    () async {
      const recorded = 'public:_apsk.recorded.a.__e$daemonAtSign';
      for (final make in clients) {
        final w = newWorld();
        w.records[pingRecordKeyOf()] = pingRecord(
          escr: true,
          signingKeyUri: recorded,
        );
        final c = make(w);
        final outcome = c.start();

        final request = await w.relayRequest(c);

        expect(
          request['preFetch'],
          contains(recorded),
          reason: "${c.name} has the relay prefetch the recorded daemon key",
        );
        await w.finish(c, outcome);
      }
    },
  );

  test('A daemon without ESCR gets legacy on its side only', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: false);
      final c = make(w);
      final outcome = c.start();

      final request = await w.relayRequest(c);
      await w.answerPing(c, pingResponse(escr: false));
      await w.answerRelay(c);
      final daemonRequest = await w.daemonRequest(c);

      expect(
        request['relayAuthModes'],
        escrThenLegacy,
        reason: '${c.name} names legacy for a daemon without ESCR only',
      );
      expect(
        daemonRequest['relayAuthMode'],
        'payload',
        reason: '${c.name} tells a daemon without ESCR to use legacy',
      );
      await w.finish(c, outcome);
    }
  });

  test(
    'A daemon whose ping names no features gets legacy on its side',
    () async {
      for (final make in clients) {
        final w = newWorld();
        final c = make(w);
        final outcome = c.start();

        await w.answerPing(c, pingResponse(escr: true, features: false));
        final request = await w.relayRequest(c);

        expect(
          (request['relayAuthModes'] as Map)['sideB'],
          'payload',
          reason: '${c.name} names legacy for a daemon that names no features',
        );
        await w.finish(c, outcome);
      }
    },
  );

  test('An explicit ESCR request with a daemon without ESCR uses ESCR on the '
      'client\'s side only', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: false);
      final c = make(w, explicitMode: RelayAuthMode.escr);
      final outcome = c.start();

      final request = await w.relayRequest(c);
      await w.answerPing(c, pingResponse(escr: false));
      await w.answerRelay(c, applied: true);

      expect(
        request['relayAuthModes'],
        escrThenLegacy,
        reason: '${c.name} names ESCR for itself and legacy for the daemon',
      );
      expect(
        (await w.daemonRequest(c))['relayAuthMode'],
        'payload',
        reason: '${c.name} goes on, telling the daemon to use legacy',
      );
      await w.finish(c, outcome);
    }
  });

  test('An explicit payload request names legacy for both sides', () async {
    for (final make in clients) {
      final w = newWorld();
      final c = make(w, explicitMode: RelayAuthMode.payload);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      final request = await w.relayRequest(c);

      expect(
        request['relayAuthModes'],
        legacyBoth,
        reason: '${c.name} names legacy for both sides under payload',
      );
      await w.finish(c, outcome);
    }
  });

  test('A 443 request names ESCR for both sides', () async {
    for (final make in clients) {
      final w = newWorld();
      final c = make(w, only443: true);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      final request = await w.relayRequest(c);

      expect(
        request['relayAuthModes'],
        escrBoth,
        reason: '${c.name} names ESCR for both sides on port 443',
      );
      await w.finish(c, outcome);
    }
  });

  test('Every request still carries the mode for relays that apply one mode to '
      'both sides', () async {
    for (final make in clients) {
      final w = newWorld();
      final c = make(w);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      final request = await w.relayRequest(c);

      expect(
        request['relayAuthMode'],
        'payload',
        reason: '${c.name} still names one mode an older relay applies',
      );
      await w.finish(c, outcome);
    }
  });

  test(
    'A relay that applies one mode to both sides gets it on both sides',
    () async {
      for (final make in clients) {
        final w = newWorld();
        final relayPort = await RelayPortA.open();
        final c = make(w);
        final outcome = c.start();

        await w.answerPing(c, pingResponse(escr: true));
        await w.answerRelay(
          c,
          applied: false,
          autoDetects: false,
          portA: relayPort.port,
        );
        final daemonRequest = await w.daemonRequest(c);
        await w.acceptSession(c);
        final String? sentToRelay = await relayPort.firstBytes;

        expect(
          sentToRelay,
          allOf(startsWith('{'), contains(c.sessionId)),
          reason:
              '${c.name} authenticates its own socket with a legacy '
              'envelope',
        );
        expect(
          daemonRequest['relayAuthMode'],
          'payload',
          reason: '${c.name} tells even an ESCR daemon to use legacy',
        );
        expect(
          await outcome.timeout(const Duration(seconds: 10)),
          isNull,
          reason: '${c.name} starts the session',
        );
      }
    },
  );

  test(
    'A relay that applied relayAuthModes is sent no auth_modes notification',
    () async {
      for (final make in clients) {
        final w = newWorld();
        w.records[pingRecordKeyOf()] = pingRecord(escr: true);
        final c = make(w);
        final outcome = c.start();

        await w.answerRelay(c, applied: true);
        await w.answerPing(c, pingResponse(escr: true));
        await w.daemonRequest(c);

        expect(
          w.authModesSentBy(c),
          isNull,
          reason:
              '${c.name} sends no auth_modes to a relay that applied '
              'relayAuthModes',
        );
        await w.finish(c, outcome);
      }
    },
  );

  test('A relay that auto-detects without applying relayAuthModes is still '
      'sent auth_modes', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: true);
      final c = make(w);
      final outcome = c.start();

      await w.answerRelay(c, applied: false, autoDetects: true);
      await w.answerPing(c, pingResponse(escr: true));
      await w.daemonRequest(c);
      final authModes = w.authModesSentBy(c);

      expect(
        authModes == null
            ? null
            : {'sideA': authModes['sideA'], 'sideB': authModes['sideB']},
        escrBoth,
        reason: '${c.name} sends auth_modes naming both sides',
      );
      await w.finish(c, outcome);
    }
  });

  test("The ping response is recorded on the client's own atServer", () async {
    for (final make in clients) {
      final w = newWorld();
      final c = make(w);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      await w.answerRelay(c);
      await w.daemonRequest(c);
      final DateTime after = DateTime.now();

      expect(w.writes, hasLength(1), reason: '${c.name} writes the record');
      final write = w.writes.single;
      expect(
        write.key,
        'cached.ping.bob.dev.sshnp@alice',
        reason: '${c.name} writes cached.ping.<daemon>.<device>.sshnp',
      );
      expect(
        write.useRemoteAtServer,
        isTrue,
        reason: "${c.name} writes to the client's own atServer",
      );
      final Map value = jsonDecode(write.value);
      expect(
        value.keys,
        unorderedEquals(['supportsRamEscr', 'publicSigningKeyUri', 'storedAt']),
        reason: '${c.name} records these three fields and nothing else',
      );
      expect(
        value['supportsRamEscr'],
        isTrue,
        reason: "${c.name} records the daemon's ESCR support",
      );
      expect(
        value['publicSigningKeyUri'],
        daemonSigningKeyUri,
        reason: "${c.name} records the daemon's signing key URI",
      );
      expect(
        after.difference(DateTime.parse(value['storedAt'])).inSeconds,
        inInclusiveRange(0, 10),
        reason: '${c.name} records when it wrote the record',
      );
      expect(
        write.ttl,
        const Duration(days: 30).inMilliseconds,
        reason: '${c.name} gives the record a 30-day ttl',
      );
      await w.finish(c, outcome);
    }
  });

  test('An unchanged recent record is not rewritten', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(
        escr: true,
        age: const Duration(days: 2),
      );
      final c = make(w);
      final outcome = c.start();

      await w.answerRelay(c);
      await w.answerPing(c, pingResponse(escr: true));
      await w.daemonRequest(c);

      expect(w.reads, isNotEmpty, reason: '${c.name} read the record');
      expect(
        w.writes,
        isEmpty,
        reason: '${c.name} does not rewrite an unchanged recent record',
      );
      await w.finish(c, outcome);
    }
  });

  group('A record is rewritten when it changed or is a week old', () {
    for (final (String age, String answer, Duration stored, String liveUri) in [
      (
        '2 days',
        'a different publicSigningKeyUri',
        const Duration(days: 2),
        'public:_apsk.another.a.__e$daemonAtSign',
      ),
      (
        '8 days',
        'the same supportsRamEscr and publicSigningKeyUri',
        const Duration(days: 8),
        daemonSigningKeyUri,
      ),
    ]) {
      test('$age | $answer', () async {
        for (final make in clients) {
          final w = newWorld();
          w.records[pingRecordKeyOf()] = pingRecord(escr: true, age: stored);
          final c = make(w);
          final outcome = c.start();

          await w.answerRelay(c);
          await w.answerPing(
            c,
            pingResponse(escr: true, signingKeyUri: liveUri),
          );
          await w.daemonRequest(c);

          expect(w.writes, hasLength(1), reason: '${c.name} rewrites it');
          final DaemonPingRecord rewritten = recordIn(w);
          expect(
            rewritten.support,
            DaemonRelayAuthSupport(
              supportsRamEscr: true,
              publicSigningKeyUri: liveUri,
            ),
            reason: '${c.name} writes the live answer',
          );
          expect(
            DateTime.now().difference(rewritten.storedAt).inSeconds,
            inInclusiveRange(0, 10),
            reason: '${c.name} writes when it rewrote the record',
          );
          await w.finish(c, outcome);
        }
      });
    }
  });

  group('A record that cannot be used is treated as absent', () {
    for (final (String defect, void Function(ClientWorld) give) in [
      (
        'cannot be read from the atServer',
        (ClientWorld w) =>
            w.readFailure = AtClientException.message('the read failed'),
      ),
      (
        'holds a value that cannot be decoded',
        (ClientWorld w) => w.records[pingRecordKeyOf()] = 'not a ping record',
      ),
    ]) {
      test(defect, () async {
        for (final make in clients) {
          final w = newWorld();
          give(w);
          final c = make(w);
          final outcome = c.start();

          await expectRelayAskedOnlyAfterPing(w, c, pingResponse(escr: true));

          expect(
            askedRelayAfterPing(w),
            isTrue,
            reason: '${c.name} waits for the ping: ${w.log}',
          );
          await w.finish(c, outcome);
        }
      });
    }
  });

  test('No record is written after a failed read', () async {
    for (final make in clients) {
      final w = newWorld();
      w.readFailure = AtClientException.message('the read failed');
      final c = make(w);
      final outcome = c.start();

      await w.answerPing(c, pingResponse(escr: true));
      await w.answerRelay(c);
      await w.daemonRequest(c);

      expect(w.reads, isNotEmpty, reason: '${c.name} tried to read');
      expect(
        w.writes,
        isEmpty,
        reason: '${c.name} writes no record after a failed read',
      );
      await w.finish(c, outcome);
    }
  });

  group("Another daemon's record is not used", () {
    for (final (String other, String otherDaemon, String otherDevice) in [
      (
        'a different device of the same daemon Atsign',
        daemonAtSign,
        'other_dev',
      ),
      ('the same device name under another Atsign', '@carol', deviceName),
    ]) {
      test(other, () async {
        for (final make in clients) {
          final w = newWorld();
          final o = make(w, daemon: otherDaemon, device: otherDevice);
          final otherOutcome = o.start();
          await w.answerPing(o, pingResponse(escr: true));
          await w.finish(o, otherOutcome);
          expect(w.records.keys, [
            pingRecordKeyOf(daemon: otherDaemon, device: otherDevice),
          ], reason: '${o.name} recorded the other daemon device only');
          SshnpdChannel.forgetLiveAnswers();

          final c = make(w);
          final outcome = c.start();
          await expectRelayAskedOnlyAfterPing(w, c, pingResponse(escr: true));
          await w.finish(c, outcome);
        }
      });
    }
  });

  test('A record that undersells the daemon is corrected without asking the '
      'relay again', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: false);
      final c = make(w);
      final outcome = c.start();

      final request = await w.relayRequest(c);
      await w.answerRelay(c, applied: true);
      await w.answerPing(c, pingResponse(escr: true));
      final daemonRequest = await w.daemonRequest(c);

      expect(
        (request['relayAuthModes'] as Map)['sideB'],
        'payload',
        reason: '${c.name} names legacy for side B, as the record says',
      );
      expect(
        daemonRequest['relayAuthMode'],
        'payload',
        reason: '${c.name} tells the daemon the mode the relay applied',
      );
      expect(
        w.sentTo('request_ports'),
        hasLength(1),
        reason: '${c.name} asks the relay once',
      );
      expect(
        recordIn(w).support.supportsRamEscr,
        isTrue,
        reason: '${c.name} corrects the record',
      );
      await w.finish(c, outcome);
    }
  });

  test('A contradicted record causes no second request to a relay that did not '
      'apply relayAuthModes', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: true);
      final c = make(w);
      final outcome = c.start();

      await w.answerRelay(c, applied: false, autoDetects: true);
      await w.answerPing(c, pingResponse(escr: false));
      final daemonRequest = await w.daemonRequest(c);

      expect(
        w.sentTo('request_ports'),
        hasLength(1),
        reason: '${c.name} asks the relay once',
      );
      expect(
        recordIn(w).support.supportsRamEscr,
        isFalse,
        reason: '${c.name} corrects the record',
      );
      expect(
        daemonRequest['relayAuthMode'],
        'payload',
        reason:
            '${c.name} goes on with the attempt, telling the daemon to '
            'use legacy',
      );
      await w.finish(c, outcome);
    }
  });

  group(
    'A record the live ping contradicts fails the attempt before the daemon '
    'is asked',
    () {
      for (final (String recorded, String now, String mode) in [
        (
          'supports ESCR',
          'no longer supports ESCR',
          'the default relay auth mode',
        ),
        ('supports ESCR', 'no longer supports ESCR', '--relay-auth-mode escr'),
        (
          'does not support ESCR',
          'now supports ESCR',
          '--relay-auth-mode escr',
        ),
      ]) {
        test('$recorded | $now | $mode', () async {
          final bool recordedEscr = recorded == 'supports ESCR';
          final bool liveEscr = now == 'now supports ESCR';
          for (final make in clients) {
            final w = newWorld();
            w.records[pingRecordKeyOf()] = pingRecord(escr: recordedEscr);
            final c = make(
              w,
              explicitMode: mode == '--relay-auth-mode escr'
                  ? RelayAuthMode.escr
                  : null,
            );
            final outcome = c.start();

            await w.answerRelay(c, applied: true);
            await w.answerPing(c, pingResponse(escr: liveEscr));
            final Object? thrown = await outcome.timeout(
              const Duration(seconds: 10),
            );

            expect(
              thrown,
              isA<SshnpError>().having(
                (e) => e.message,
                'message',
                contains('relay auth support changed since it was last seen'),
              ),
              reason: '${c.name} fails the attempt, saying why',
            );
            expect(
              w.sentTo(c.daemonRequestKey),
              isEmpty,
              reason: '${c.name} sends the daemon no session request',
            );
            expect(
              recordIn(w).support.supportsRamEscr,
              liveEscr,
              reason: '${c.name} records what the live ping said',
            );
          }
        });
      }
    },
  );

  test('The next attempt in the same process uses the live answer even if the '
      'record was not rewritten', () async {
    for (final make in clients) {
      final w = newWorld();
      w.records[pingRecordKeyOf()] = pingRecord(escr: true);
      w.writeFailure = AtClientException.message('the write was refused');
      final first = make(w);
      final firstOutcome = first.start();
      await w.answerRelay(first, applied: true);
      await w.answerPing(first, pingResponse(escr: false));
      expect(
        await firstOutcome.timeout(const Duration(seconds: 10)),
        isA<SshnpError>(),
        reason: '${first.name} failed the first attempt',
      );
      expect(
        recordIn(w).support.supportsRamEscr,
        isTrue,
        reason: 'the refused rewrite left the record saying ESCR',
      );

      final next = make(w);
      final outcome = next.start();
      final request = await w.relayRequest(next);

      expect(
        (request['relayAuthModes'] as Map)['sideB'],
        'payload',
        reason: '${next.name} uses the live answer of the first attempt',
      );
      await w.answerPing(next, pingResponse(escr: false));
      await w.finish(next, outcome);
    }
  });
}
