import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/service_status_check.dart';
import 'package:noports_core/src/sshnpd/doctor/diagnostic_check.dart';
import 'package:noports_core/src/sshnpd/doctor/utils/platform_utils.dart';
import 'package:test/test.dart';

class MockPlatformUtils extends Mock implements PlatformUtils {}

Future<CheckResult> runCheck({
  required bool processVisible,
  required bool serviceInstalled,
  required bool serviceRunning,
  ServiceExitInfo? exitInfo,
}) {
  final platform = MockPlatformUtils();
  when(
    () => platform.isDaemonRunning('sshnpd'),
  ).thenAnswer((_) async => processVisible);
  when(
    () => platform.isServiceInstalled('sshnpd'),
  ).thenAnswer((_) async => serviceInstalled);
  when(
    () => platform.isServiceRunning('sshnpd'),
  ).thenAnswer((_) async => serviceRunning);
  when(
    () => platform.getServiceExitInfo('sshnpd'),
  ).thenAnswer((_) async => exitInfo ?? ServiceExitInfo());
  return ServiceStatusCheck(platform: platform).run({});
}

void main() {
  group('Given the service manager reports sshnpd running '
      'but no sshnpd process is found', () {
    test('when the service status check runs, '
        'then it warns that the process may be restarting or hidden, '
        'not that the service is stopped', () async {
      final result = await runCheck(
        processVisible: false,
        serviceInstalled: true,
        serviceRunning: true,
      );
      expect(
        result.message,
        'The service manager reports sshnpd RUNNING,'
        ' but no sshnpd process was found:'
        ' it may be restarting, or hidden from this user.'
        '\n      System Service: Installed, Running',
        reason: 'a missing process is not claimed to be hidden',
      );
      expect(result.status, CheckStatus.warning);
    });

    test('when the service manager has exit details, '
        'then the warning includes them', () async {
      final result = await runCheck(
        processVisible: false,
        serviceInstalled: true,
        serviceRunning: true,
        exitInfo: ServiceExitInfo(
          exitCode: 0,
          result: 'success',
          activeState: 'active',
          subState: 'running',
        ),
      );
      expect(
        result.message,
        'The service manager reports sshnpd RUNNING,'
        ' but no sshnpd process was found:'
        ' it may be restarting, or hidden from this user.'
        '\n      System Service: Installed, Running'
        '\n      Exit Code: 0'
        '\n      Result: success'
        '\n      Active State: active (running)',
        reason: 'exit details are reported as on the stopped path',
      );
      expect(result.status, CheckStatus.warning);
    });
  });

  group('Given sshnpd is installed as a service that is not running '
      'and no sshnpd process is visible', () {
    test(
      'when the service status check runs, '
      'then it reports the process stopped and the service not running',
      () async {
        final result = await runCheck(
          processVisible: false,
          serviceInstalled: true,
          serviceRunning: false,
        );
        expect(
          result.message,
          'The sshnpd process is STOPPED.'
          '\n      System Service: Installed but not running.',
        );
        expect(result.status, CheckStatus.warning);
      },
    );
  });

  group('Given sshnpd is not installed as a service '
      'and no sshnpd process is visible', () {
    test(
      'when the service status check runs, '
      'then it reports the process stopped and the service not installed',
      () async {
        final result = await runCheck(
          processVisible: false,
          serviceInstalled: false,
          serviceRunning: false,
        );
        expect(
          result.message,
          'The sshnpd process is STOPPED.'
          '\n      System Service: Not Installed.',
        );
        expect(result.status, CheckStatus.warning);
      },
    );
  });

  group('Given an sshnpd process is visible', () {
    test('when the service status check runs, '
        'then it reports the process active', () async {
      final result = await runCheck(
        processVisible: true,
        serviceInstalled: true,
        serviceRunning: true,
      );
      expect(
        result.message,
        'The service process is ACTIVE.'
        '\n      System Service: Installed'
        '\n      Service Status: Running',
      );
      expect(result.status, CheckStatus.pass);
    });
  });
}
