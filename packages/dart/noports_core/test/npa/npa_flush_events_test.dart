import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/events.dart';
import 'package:noports_core/npa.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

/// A policy service's rules; these tests never ask it anything.
class NoRules implements NPARequestHandler {
  @override
  bool hasRulesFor(Atsign daemonAtsign) => false;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest request) =>
      throw UnimplementedError();
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeNotificationParams());
  });

  test('when a send never completes, flushEvents gives up after its timeout and'
      ' says so at SHOUT, rather than hanging', () async {
    final atClient = MockAtClient();
    final notificationService = MockNotificationService();
    when(() => atClient.getCurrentAtSign()).thenReturn('@policy');
    when(() => atClient.notificationService).thenReturn(notificationService);
    // An atServer that never answers: every notify stays pending.
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSuccess: any(named: 'onSuccess'),
        onError: any(named: 'onError'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer((_) => Completer<NotificationResult>().future);

    final npa =
        NPAImpl(
            atClient: atClient,
            homeDirectory: Directory.systemTemp.path,
            handler: NoRules(),
            eventLoggingAtsign: '@events'.toAtsign(),
          )
          ..elc = AtEventConfig(
            atSign: '@events'.toAtsign(),
            topic: 'abc123.events.logging.sshnp',
            ttln: 60000,
          );
    final shouts = <String>[];
    final subscription = npa.logger.logger.onRecord
        .where((r) => r.level >= Level.SHOUT)
        .listen((r) => shouts.add(r.message));
    addTearDown(subscription.cancel);

    await npa.sendEvent({'event': 'test'});
    final stopwatch = Stopwatch()..start();
    await npa.flushEvents(timeout: const Duration(milliseconds: 200));

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
    expect(shouts, contains(startsWith('Gave up waiting')));
  }, timeout: const Timeout(Duration(seconds: 10)));
}
