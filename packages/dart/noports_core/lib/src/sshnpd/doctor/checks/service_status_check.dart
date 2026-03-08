import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';

class ServiceStatusCheck extends DiagnosticCheck {
  @override
  String get name => 'Service Status (Daemon)';

  @override
  String get description => 'Checks if sshnpd is running in the background';

  @override
  Future<CheckResult> run() async {
    final start = DateTime.now();
    final serviceName = 'sshnpd';

    // 1. Check Process (Is the binary executing?)
    bool processRunning = await PlatformUtils.instance.isProcessRunning(serviceName);

    // 2. Check Service (Is it registered with systemd/launchd/Windows Service?)
    bool serviceInstalled = await PlatformUtils.instance.isServiceInstalled(serviceName);
    bool serviceRunning = false;
    if (serviceInstalled) {
      serviceRunning = await PlatformUtils.instance.isServiceRunning(serviceName);
    }

    if (processRunning) {
      String message = 'The service process is ACTIVE.';
      if (serviceInstalled) {
        message += '\n      System Service: Installed';
        message += '\n      Service Status: ${serviceRunning ? "Running" : "Stopped"}';
      } else {
        message += '\n      System Service: Not Installed (running manually?)';
      }

      return CheckResult(
        checkName: name,
        status: CheckStatus.pass,
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

      return CheckResult(
        checkName: name,
        status: CheckStatus.warning,
        message: message,
        duration: DateTime.now().difference(start),
      );
    }
  }
}
