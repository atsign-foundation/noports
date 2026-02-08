import 'dart:io';
import 'package:noports_core/src/sshnpd/diagnostic_runner.dart';
import 'package:noports_core/src/sshnpd/diagnostic_test.dart';
import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';
import 'package:noports_core/src/sshnpd/tests/keys_check_test.dart';
import 'package:noports_core/src/sshnpd/tests/prerequisites_test.dart';
import 'package:noports_core/src/sshnpd/tests/service_status_test.dart';
import 'package:noports_core/src/sshnpd/tests/config_check_test.dart';
import 'package:noports_core/src/sshnpd/tests/version_check_test.dart';

class SshnpdDoctor {
  Future<void> run() async {
    print('--- 🧪 DOCTOR PLAYGROUND ---');

  final runner = DiagnosticRunner(
    verbose: true,
    tests: [
      PrerequisitesTest(), // Test 1 : Outils
      KeysCheckTest(), // Test 2 : Clés (NOUVEAU)
      ServiceStatusTest(), // Test 3 : Statut du service
      ConfigCheckTest(), // Test 4 : Configuration
      VersionCheckTest(), // Test 5 : Version
    ],
  );
// ÉTAPE 1 : On lance les tests et on RÉCUPÈRE les résultats dans une variable
  final results = await runner.runAll();

  // ÉTAPE 2 : On demande au runner de générer le texte du résumé
  String summary = runner.generateSummary(results);

  // ÉTAPE 3 : On AFFICHE le tout dans la console !
  print(summary);
  }
}
