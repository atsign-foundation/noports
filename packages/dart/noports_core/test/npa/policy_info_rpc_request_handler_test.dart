import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/npa.dart';
import 'package:noports_core/src/events/noports_event_types.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

class FakeNotificationParams extends Fake implements NotificationParams {}

/// Answers every policy check with whatever [answer] returns or throws.
class FakeRequestHandler implements NPARequestHandler {
  FakeRequestHandler(this.answer);

  final Future<NPAAuthCheckResponse> Function() answer;

  @override
  bool hasRulesFor(Atsign daemonAtsign) => true;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(NPAAuthCheckRequest request) =>
      answer();
}

void main() {
  const String daemon = '@daemon';

  late MockAtClient atClient;
  late MockNotificationService notificationService;
  late List<Map<String, dynamic>> events;

  setUpAll(() {
    registerFallbackValue(FakeNotificationParams());
  });

  setUp(() {
    atClient = MockAtClient();
    notificationService = MockNotificationService();
    events = [];

    when(() => atClient.getCurrentAtSign()).thenReturn('@policy');
    when(() => atClient.notificationService).thenReturn(notificationService);
    // The handler's existing self-notification goes through here.
    when(
      () => notificationService.notify(
        any(),
        checkForFinalDeliveryStatus: any(named: 'checkForFinalDeliveryStatus'),
        waitForFinalDeliveryStatus: any(named: 'waitForFinalDeliveryStatus'),
        onSuccess: any(named: 'onSuccess'),
        onError: any(named: 'onError'),
        onSentToSecondary: any(named: 'onSentToSecondary'),
      ),
    ).thenAnswer(
      (_) async =>
          NotificationResult()
            ..notificationStatusEnum = NotificationStatusEnum.delivered,
    );
  });

  PolicyInfoRpcRequestHandler handlerFor(
    Future<NPAAuthCheckResponse> Function() answer, {
    Future<void> Function(Map<String, dynamic> event)? onEvent,
  }) => PolicyInfoRpcRequestHandler(
    policyAtsign: '@policy'.toAtsign(),
    namespace: 'sshnp',
    handler: FakeRequestHandler(answer),
    atClient: atClient,
    onEvent: onEvent ?? (e) async => events.add(e),
  );

  AtRpcReq requestAbout(String daemonAtsign) => AtRpcReq(
    reqId: 1,
    payload: NPAAuthCheckRequest(
      daemonAtsign: daemonAtsign,
      daemonDeviceName: 'dev1',
      daemonDeviceGroupName: 'group1',
      clientAtsign: '@client',
    ).toJson(),
  );

  NPAAuthCheckResponse answerIn(AtRpcResp resp) =>
      NPAAuthCheckResponse.fromJson(resp.payload);

  group('PolicyInfoRpcRequestHandler policy events', () {
    test('an admitted client is logged as clientAdmitted', () async {
      final h = handlerFor(
        () async => NPAAuthCheckResponse(
          authorized: true,
          message: 'ok',
          permitOpen: ['localhost:22'],
        ),
      );

      await h.handleRequest(requestAbout(daemon), daemon);

      expect(events, hasLength(1));
      final e = events.single;
      expect(e['event'], PolicyEventType.clientAdmitted.name);
      expect(e['policyAtsign'], '@policy');
      expect(e['fromAtsign'], daemon);
      expect(e['clientAtsign'], '@client');
      expect(e['daemonAtsign'], daemon);
      expect(e['daemonDeviceName'], 'dev1');
      expect(e['daemonDeviceGroupName'], 'group1');
      expect(e['message'], 'ok');
      expect(e['permitOpen'], ['localhost:22']);
      expect(e['timestamp'], isA<String>());
    });

    test('a refused client is logged as clientRejected', () async {
      final h = handlerFor(
        () async => NPAAuthCheckResponse(
          authorized: false,
          message: 'no rule for @client',
          permitOpen: [],
        ),
      );

      await h.handleRequest(requestAbout(daemon), daemon);

      expect(events, hasLength(1));
      expect(events.single['event'], PolicyEventType.clientRejected.name);
      expect(events.single['message'], 'no rule for @client');
      expect(events.single['fromAtsign'], daemon);
    });

    test(
      'a daemon asking about another daemon is logged as clientRejected',
      () async {
        final h = handlerFor(() => fail('the policy check must not run'));

        final resp = await h.handleRequest(requestAbout(daemon), '@other');

        expect(answerIn(resp).authorized, isFalse);
        expect(events, hasLength(1));
        expect(events.single['event'], PolicyEventType.clientRejected.name);
        expect(events.single['message'], 'A daemon may ask only about itself');
        expect(events.single['fromAtsign'], '@other');
      },
    );

    test('a policy check that throws is logged as policyCheckFailed, '
        'and the client is still refused', () async {
      final h = handlerFor(() async => throw Exception('boom'));

      final resp = await h.handleRequest(requestAbout(daemon), daemon);

      expect(answerIn(resp).authorized, isFalse);
      expect(events, hasLength(1));
      expect(events.single['event'], PolicyEventType.policyCheckFailed.name);
      expect(events.single['fromAtsign'], daemon);
      expect(events.single['error'], contains('boom'));
    });

    test('a failing event log does not change the answer', () async {
      final h = handlerFor(
        () async => NPAAuthCheckResponse(
          authorized: true,
          message: 'ok',
          permitOpen: [],
        ),
        onEvent: (_) async => throw Exception('event log down'),
      );

      final resp = await h.handleRequest(requestAbout(daemon), daemon);

      expect(answerIn(resp).authorized, isTrue);
    });

    test('no events are sent when there is no onEvent', () async {
      final h = PolicyInfoRpcRequestHandler(
        policyAtsign: '@policy'.toAtsign(),
        namespace: 'sshnp',
        handler: FakeRequestHandler(
          () async => NPAAuthCheckResponse(
            authorized: true,
            message: 'ok',
            permitOpen: [],
          ),
        ),
        atClient: atClient,
      );

      final resp = await h.handleRequest(requestAbout(daemon), daemon);

      expect(answerIn(resp).authorized, isTrue);
      expect(events, isEmpty);
    });
  });
}
