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
}) {
  final platform = MockPlatformUtils();
  when(
    () => platform.isProcessRunning('sshnpd'),
  ).thenAnswer((_) async => processVisible);
  when(
    () => platform.isServiceInstalled('sshnpd'),
  ).thenAnswer((_) async => serviceInstalled);
  when(
    () => platform.isServiceRunning('sshnpd'),
  ).thenAnswer((_) async => serviceRunning);
  when(
    () => platform.getServiceExitInfo('sshnpd'),
  ).thenAnswer((_) async => ServiceExitInfo());
  return ServiceStatusCheck(platform: platform).run({});
}

void main() {
  group('Given the service manager reports sshnpd running '
      'but its process is not visible to this user', () {
    test('when the service status check runs, '
        'then it reports the service running with its process not visible, '
        'not stopped', () async {
      final result = await runCheck(
        processVisible: false,
        serviceInstalled: true,
        serviceRunning: true,
      );
      expect(
        result.message,
        'The service manager reports sshnpd RUNNING,'
        ' but this user cannot see its process.'
        '\n      System Service: Installed, Running'
        ' (its process is not visible to this user)',
        reason: 'a running service is not reported as stopped',
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
