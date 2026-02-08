import 'dart:io';
import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class ConfigCheckTest extends DiagnosticTest {
  @override
  String get name => 'Config Check (sshnpd.yaml)';

  @override
  String get description =>
      'Checks for the presence and content of the config file';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();

    // Liste des endroits potentiels où chercher le fichier, fournie par PlatformUtils
    List<String> potentialPaths = PlatformUtils.instance.getPotentialConfigPaths();

    for (var path in potentialPaths) {
      File configFile = File(path);

      if (await configFile.exists()) {
        // On a trouvé le fichier ! On va lire les premières lignes pour info
        try {
          String content = await configFile.readAsString();

          // Petite astuce : on extrait juste les lignes importantes pour l'affichage
          // On cherche les lignes qui contiennent "manager" ou "device"
          var importantLines = content
              .split('\n')
              .where(
                  (line) => line.contains('manager') || line.contains('device'))
              .map((l) => l.trim())
              .join(', ');

          return TestResult(
            testName: name,
            status: TestStatus.pass,
            message: 'File found at: $path\n      Preview: $importantLines',
            duration: DateTime.now().difference(start),
          );
        } catch (e) {
          return TestResult(
            testName: name,
            status: TestStatus.warning,
            message: 'File found ($path) but impossible to read it: $e',
            duration: DateTime.now().difference(start),
          );
        }
      }
    }

    // Si on sort de la boucle sans rien trouver
    return TestResult(
      testName: name,
      status: TestStatus
          .warning, // Orange, car on peut lancer sshnpd sans fichier (avec des arguments)
      message:
          'No sshnpd.yaml file found (this is not a problem if you are using CLI arguments).',
      duration: DateTime.now().difference(start),
    );
  }
}
