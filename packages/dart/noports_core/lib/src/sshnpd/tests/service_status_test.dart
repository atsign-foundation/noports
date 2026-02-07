import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class ServiceStatusTest extends DiagnosticTest {
  @override
  String get name => 'Service Status (Daemon)';

  @override
  String get description => 'Checks if sshnpd is running in the background';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();

    // 1. Check Process (Is the binary executing?)
    bool processRunning = await PlatformUtils.instance.isProcessRunning('sshnpd');

    // 2. Check Service (Is it registered with systemd/launchd/Windows Service?)
    bool serviceInstalled = await PlatformUtils.instance.isServiceInstalled('sshnpd');
    bool serviceRunning = false;
    if (serviceInstalled) {
      serviceRunning = await PlatformUtils.instance.isServiceRunning('sshnpd');
    }

    if (processRunning) {
      String message = 'The service process is ACTIVE.';
      if (serviceInstalled) {
        message += '\n      System Service: Installed';
        message += '\n      Service Status: ${serviceRunning ? "Running" : "Stopped"}';
      } else {
        message += '\n      System Service: Not Installed (running manually?)';
      }

      return TestResult(
        testName: name,
        status: TestStatus.pass,
        message: message,
        duration: DateTime.now().difference(start),
      );
    } else {
      String message = 'The sshnpd process is STOPPED.';
      if (serviceInstalled) {
         message += '\n      System Service: Installed but not running.';
      } else {
         message += '\n      System Service: Not Installed.';
      }

      return TestResult(
        testName: name,
        status: TestStatus.warning,
        message: message,
        duration: DateTime.now().difference(start),
      );
    }
  }
}
