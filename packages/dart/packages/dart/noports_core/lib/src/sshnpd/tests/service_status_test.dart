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

    // On utilise PlatformUtils pour vérifier le process de manière compatible OS
    bool running = await PlatformUtils.instance.isProcessRunning('sshnpd');

    if (running) {
      // Si running est vrai, le processus est trouvé
      return TestResult(
        testName: name,
        status: TestStatus.pass,
        message: 'The service is ACTIVE.',
        duration: DateTime.now().difference(start),
      );
    } else {
      // Aucun processus trouvé.
      return TestResult(
        testName: name,
        status: TestStatus
            .warning, // Ce n'est pas forcément une erreur grave, peut-être qu'il est juste éteint.
        message: 'The sshnpd service is STOPPED (no process found).',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
