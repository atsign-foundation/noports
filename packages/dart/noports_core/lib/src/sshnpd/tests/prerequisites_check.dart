import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class PrerequisitesCheck extends DiagnosticTest {
  @override
  String get name => 'Prerequisites Check';

  @override
  String get description => 'Checks for the presence of curl and ssh';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();
    List<String> missingTools = [];

    var tools = ['curl', 'ssh'];

    for (var tool in tools) {
      bool available = await PlatformUtils.instance.isCommandAvailable(tool);
      if (!available) {
        missingTools.add(tool);
      }
    }

    if (missingTools.isEmpty) {
      return TestResult(
        testName: name,
        status: TestStatus.pass,
        message: 'Every required tool is present (curl, ssh, unzip).',
        duration: DateTime.now().difference(start),
      );
    } else {
      return TestResult(
        testName: name,
        status: TestStatus.fail, // C'm bloquant !
        message: 'Missing required tools: ${missingTools.join(', ')}',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
