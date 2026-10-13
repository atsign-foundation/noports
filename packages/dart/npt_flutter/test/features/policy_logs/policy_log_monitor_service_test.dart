import 'dart:async';
import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:noports_core/npa.dart'
    show NPAAuthCheckRequest, NPAAuthCheckResponse;
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/policy_logs/services/policy_log_monitor_service.dart';

import '../profile/repository/profile_repository_test.mocks.dart';

/// Delivers a notification only when it matches the subscribed regex, as
/// at_client does.
class _Notifications implements NotificationService {
  final _controller = StreamController<AtNotification>(sync: true);
  String? _regex;

  @override
  Stream<AtNotification> subscribe({String? regex, bool shouldDecrypt = false}) {
    _regex = regex;
    return _controller.stream;
  }

  bool deliver(AtNotification notification) {
    if (!RegExp(_regex!).hasMatch(notification.key)) return false;
    _controller.add(notification);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

AtNotification _policyLog({required String from, int id = 1}) {
  final request = AtRpcReq(
    reqId: id,
    payload: NPAAuthCheckRequest(
      daemonAtsign: '@lab',
      daemonDeviceName: 'lab01',
      daemonDeviceGroupName: 'labs',
      clientAtsign: '@alice',
    ).toJson(),
  );
  final response = AtRpcResp(
    reqId: id,
    respType: AtRpcRespType.success,
    payload: NPAAuthCheckResponse(
      authorized: true,
      message: 'ok',
      permitOpen: ['localhost:22'],
    ).toJson(),
  );
  return AtNotification.empty()
    ..from = from
    ..to = '@policy'
    ..key = '@policy:170000000000$id.logs.policy.sshnp$from'
    ..value = jsonEncode({
      'daemon': '@lab',
      'timestamp': 0,
      'payload': {'request': request, 'response': response},
    });
}

AtNotification _heartbeat() => AtNotification.empty()
  ..from = '@lab'
  ..to = '@policy'
  ..key = '@policy:lab01.devices.policy.sshnp@lab'
  ..value = jsonEncode({
    'devicename': 'lab01',
    'deviceGroupName': 'labs',
    'allowedServices': ['localhost:22'],
  });

const _authorized = 'Request: @alice → @lab (AUTHORIZED - Permit: localhost:22)';

Future<LogsCubit> _pumpAppLog(WidgetTester tester) async {
  final logs = LogsCubit();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider.value(value: logs),
      ],
      child: MaterialApp(navigatorKey: App.navState, home: const SizedBox()),
    ),
  );
  return logs;
}

void main() {
  final modes = <String, Future<void> Function(PolicyLogMonitorService)>{
    'monitoring all devices': (s) => s.startGlobalMonitoring(),
    'monitoring chosen devices': (s) => s.startMonitoring(['lab01']),
  };

  late _Notifications notifications;
  late PolicyLogMonitorService service;

  setUp(() {
    notifications = _Notifications();
    final atClient = MockAtClient();
    when(atClient.getCurrentAtSign()).thenReturn('@policy');
    when(atClient.notificationService).thenReturn(notifications);
    service = PolicyLogMonitorService.withAtClient(atClient);
  });

  tearDown(() => service.stopMonitoring());

  modes.forEach((mode, start) {
    group('Given npt_flutter signed in as @policy, $mode', () {
      testWidgets('P1: the policy service\'s own log shows as a policy request', (
        tester,
      ) async {
        await _pumpAppLog(tester);
        await start(service);

        expect(notifications.deliver(_policyLog(from: '@policy')), isTrue);

        expect(service.logs, hasLength(1), reason: 'P1: shown');
        expect(service.logs.single.type, 'policy request');
        expect(service.logs.single.fromAtsign, '@policy');
        expect(service.logs.single.allowedServices, _authorized);
      });

      for (final sender in ['@carol', '@lab']) {
        testWidgets(
          'P2: a policy log from $sender is not shown, and the app log names '
          'the sender',
          (tester) async {
            final appLog = await _pumpAppLog(tester);
            await start(service);

            expect(notifications.deliver(_policyLog(from: sender)), isTrue);
            expect(
              notifications.deliver(_policyLog(from: '@policy', id: 2)),
              isTrue,
            );

            expect(
              service.logs.map((e) => e.fromAtsign),
              ['@policy'],
              reason: 'P2: only the policy service\'s own log is shown',
            );
            expect(
              appLog.logs.map((e) => '${e.loggable}'),
              contains(
                allOf(contains('ignored policy log'), contains('from $sender')),
              ),
              reason: 'P2: the app log names the sender',
            );
          },
        );
      }

      testWidgets('P3: a heartbeat shows with its sender', (tester) async {
        await _pumpAppLog(tester);
        await start(service);

        expect(notifications.deliver(_heartbeat()), isTrue);

        expect(service.logs, hasLength(1), reason: 'P3: shown');
        expect(service.logs.single.type, 'heartbeat');
        expect(service.logs.single.fromAtsign, '@lab');
        expect(service.logs.single.deviceName, 'lab01');
      });
    });
  });
}
