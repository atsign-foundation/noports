import 'dart:convert';

import 'package:noports_core/src/srvd/telemetry/opted_in_list.dart';
import 'package:noports_core/src/srvd/telemetry/relay_telemetry_names.dart';
import 'package:test/test.dart';

import 'telemetry_fakes.dart';

/// The value an AtCollection stores for an item holding [obj].
String item(Object obj) => jsonEncode({'type': 'n/a', 'obj': obj});

String manifest(int chunks, {DateTime? builtAt}) => item({
      'builtAt': (builtAt ?? DateTime.timestamp()).toUtc().toIso8601String(),
      'chunks': chunks,
      'window': '30d',
    });

void main() {
  late Map<String, String> stored;
  late CollectionOptedInListSource source;
  late List<String> warnings;

  setUp(() {
    stored = {};
    source = CollectionOptedInListSource(readItem: (id) async => stored[id]);
    warnings = [];
  });

  OptedInListPoller poller(
    OptedInListSource from, {
    Duration interval = const Duration(days: 1),
    DateTime Function()? now,
  }) =>
      OptedInListPoller(
        source: from,
        interval: interval,
        firstRetryFrom: const Duration(milliseconds: 20),
        firstRetryTo: const Duration(milliseconds: 40),
        laterRetryFrom: const Duration(milliseconds: 20),
        onWarning: warnings.add,
        now: now,
      );

  test('The list is read from the collection at start and every 15 minutes',
      () async {
    expect(OptedInListPoller.defaultInterval, const Duration(minutes: 15));
    stored['manifest'] = manifest(2);
    stored['chunk-0000'] = item({'atsigns': ['@alice', '@bob']});
    stored['chunk-0001'] = item({'atsigns': ['@carol']});
    final List<String> asked = [];
    final counting = CollectionOptedInListSource(readItem: (id) async {
      asked.add(id);
      return stored[id];
    });
    final p = poller(counting, interval: const Duration(milliseconds: 100));
    addTearDown(p.stop);

    p.start();
    await p.firstGoodRead.timeout(const Duration(seconds: 2));

    expect(asked.take(3), ['manifest', 'chunk-0000', 'chunk-0001']);
    expect(p.list!.atsigns, {'@alice', '@bob', '@carol'});
    await until(() => asked.where((id) => id == 'manifest').length >= 3,
        what: 'two more scheduled reads');
  });

  test('Nothing is reported before the first good read', () async {
    final scripted = ScriptedListSource();
    final p = poller(scripted);
    addTearDown(p.stop);

    p.start();
    await until(() => scripted.reads >= 3, what: 'retries');

    expect(p.usable, isFalse);
    expect(p.listed('@alice'), isFalse);
    expect(warnings, isNotEmpty);
    scripted.list = listOf(['@alice']);
    await p.firstGoodRead.timeout(const Duration(seconds: 2));
    expect(p.listed('@alice'), isTrue);
  });

  test('An inconsistent read is refused and the previous list kept', () async {
    stored['manifest'] = manifest(1);
    stored['chunk-0000'] = item({'atsigns': ['@alice']});
    expect((await source.read()).atsigns, {'@alice'});

    stored['manifest'] = manifest(2);

    await expectLater(source.read(), throwsStateError);
    final p = poller(source, interval: const Duration(milliseconds: 50));
    addTearDown(p.stop);
    stored['manifest'] = manifest(1);
    p.start();
    await p.firstGoodRead.timeout(const Duration(seconds: 2));
    stored['manifest'] = manifest(2);
    await until(() => warnings.isNotEmpty, what: 'a refused read');
    expect(p.list!.atsigns, {'@alice'});
    expect(p.usable, isTrue);
  });

  test('A list holding an entry that is not a canonical Atsign is refused whole',
      () async {
    stored['manifest'] = manifest(1);
    stored['chunk-0000'] = item({'atsigns': ['@alice', 'Alice']});

    await expectLater(source.read(), throwsFormatException);

    stored['chunk-0000'] = item({'atsigns': ['@alice']});
    final p = poller(source, interval: const Duration(milliseconds: 50));
    addTearDown(p.stop);
    p.start();
    await p.firstGoodRead.timeout(const Duration(seconds: 2));
    stored['chunk-0000'] = item({'atsigns': ['@alice', '@Bob']});
    await until(() => warnings.isNotEmpty, what: 'a refused read');
    expect(p.list!.atsigns, {'@alice'});
  });

  test('A list older than a day stops new sessions being reported', () async {
    expect(OptedInListPoller.defaultMaxAge, const Duration(hours: 24));
    DateTime clock = DateTime.utc(2026, 11, 8, 12);
    final scripted = ScriptedListSource(
      listOf(['@alice'], builtAt: clock.subtract(const Duration(hours: 25))),
    );
    final p = poller(scripted, now: () => clock);
    addTearDown(p.stop);
    p.start();
    await p.firstGoodRead.timeout(const Duration(seconds: 2));
    scripted.list = null;

    expect(p.listed('@alice'), isFalse);
    expect(p.listed('@alice'), isFalse);
    expect(warnings.where((w) => w.contains('over the 24 hour limit')),
        hasLength(1), reason: 'warned once on the change');
    clock = clock.add(const Duration(minutes: 61));
    expect(p.usable, isFalse);
    expect(warnings.where((w) => w.contains('over the 24 hour limit')),
        hasLength(2), reason: 'then once an hour');

    final telemetryExporter = RecordingExporter();
    // NOTE the telemetry reads the real clock, so its list is built now.
    final telemetrySource =
        ScriptedListSource(listOf(['@alice'], builtAt: DateTime.timestamp()));
    final telemetry = await startedTelemetry(telemetryExporter, telemetrySource);
    addTearDown(telemetry.stop);
    telemetry.connectionOpened(
      'the-session',
      sessionInfo(sessionParams()),
      opened(1),
    );
    expect(telemetry.reporting('the-session'), isTrue,
        reason: 'a fresh list reports, the control for the stale one');
    expect(
      telemetryExporter.named(RelayTelemetryNames.sessionStarted),
      hasLength(1),
    );
  });

  test('a manifest built in the future is refused', () async {
    stored['manifest'] = manifest(0,
        builtAt: DateTime.timestamp().add(const Duration(minutes: 10)));

    await expectLater(source.read(), throwsFormatException);
  });

  test('a manifest whose builtAt names no time zone is refused', () async {
    final String local =
        DateTime.timestamp().toIso8601String().replaceAll('Z', '');
    stored['manifest'] =
        item({'builtAt': local, 'chunks': 0, 'window': '30d'});

    await expectLater(source.read(), throwsFormatException,
        reason: 'builtAt is UTC, so a time without a zone is not read as local');
  });

  test('an empty list is a good read', () async {
    stored['manifest'] = manifest(0);

    expect((await source.read()).atsigns, isEmpty);
  });
}
