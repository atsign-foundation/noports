import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class ServiceLogsCheck extends DiagnosticTest {
  @override
  String get name => 'Service Logs';

  @override
  String get description => 'Fetches recent logs from the system service manager (journalctl/EventLog/log)';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();

    // Check if service is installed first, otherwise logs might be irrelevant or empty
    bool serviceInstalled = await PlatformUtils.instance.isServiceInstalled('sshnpd');
    
    if (!serviceInstalled) {
       // If service is not installed, but process is running, we should hint the user
       bool processRunning = await PlatformUtils.instance.isProcessRunning('sshnpd');
       if (processRunning) {
         return TestResult(
          testName: name,
          status: TestStatus.warning, 
          message: 'Service is not installed (running manually?), check your terminal for logs.',
          duration: DateTime.now().difference(start),
        );
       }

       return TestResult(
        testName: name,
        status: TestStatus.warning,
        message: 'Service is not installed, cannot fetch system logs.',
        duration: DateTime.now().difference(start),
      );
    }

    String logs = await PlatformUtils.instance.getServiceLogs('sshnpd');
    
    // Truncate if too long (although we requested 50 lines)
    if (logs.length > 2000) {
      logs = '${logs.substring(0, 2000)}\n... (truncated)';
    }

    if (logs.trim().isEmpty) {
      return TestResult(
        testName: name,
        status: TestStatus.warning,
        message: 'No logs found or empty log output.',
        duration: DateTime.now().difference(start),
      );
    }

    return TestResult(
      testName: name,
      status: TestStatus.pass,
      message: 'Client Logs:\n$logs',
      duration: DateTime.now().difference(start),
    );
  }
}
