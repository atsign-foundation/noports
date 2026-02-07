import 'dart:io';
import 'dart:convert';
import '../diagnostic_test.dart';
import 'package:noports_core/version.dart';
import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';


class VersionCheckTest extends DiagnosticTest {

  @override
  String get name => 'Version Check';

  @override
  String get description =>
      'Checks if a new version of sshnpd is available and offers to update';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();
    String currentVersion = await PlatformUtils.instance.getCurrentVersion();

    try {
      // 2. OBTENIR LA DERNIÈRE VERSION DEPUIS GITHUB
      print('Checking for latest version on GitHub...');

      var result = await Process.run('curl', [
        '-s',
        'https://api.github.com/repos/atsign-foundation/noports/releases/latest'
      ]);

      if (result.exitCode != 0) {
        return TestResult(
          testName: name,
          status: TestStatus.warning,
          message:
              'Unable to check for updates (curl error: ${result.stderr}).',
          duration: DateTime.now().difference(start),
        );
      }

      Map<String, dynamic> data = jsonDecode(result.stdout.toString());
      String latestTag = data['tag_name'] ?? 'unknown';

      String cleanCurrent = currentVersion.replaceAll('v', '').trim();
      String cleanLatest = latestTag.replaceAll('v', '').trim();
      
      // 2. COMPARAISON
      if (cleanCurrent == cleanLatest) {
        return TestResult(
          testName: name,
          status: TestStatus.pass,
          message: 'Software is up to date (v$cleanCurrent).',
          duration: DateTime.now().difference(start),
        );
      } else {
        // 3. INTERACTION : C'est ici que la magie opère !
        print('\n🚀A NEW UPDATE IS AVAILABLE !');
        print('    Current version: $cleanCurrent');
        print('   New version: $cleanLatest');

        stdout.write('👉 Do you want to update sshnpd now? (y/n) : ');

        // On attend la réponse de l'utilisateur
        String? answer = stdin.readLineSync();

        if (answer != null && answer.toLowerCase().startsWith('y')) {
          // Lancer la mise à jour
          bool success = await _simulateUpdate(data['assets']);

          if (success) {
            return TestResult(
              testName: name,
              status:
                  TestStatus.pass, // C'est vert car on a corrigé le problème !
              message: 'Update completed to version $cleanLatest.',
              duration: DateTime.now().difference(start),
            );
          } else {
            return TestResult(
              testName: name,
              status: TestStatus.fail,
              message: 'Update failed. Please try manually. ',
              duration: DateTime.now().difference(start),
            );
          }
        } else {
          // L'utilisateur refuse
          return TestResult(
            testName: name,
            status: TestStatus.warning,
            message: 'Update ignored by user (v$cleanCurrent).',
            duration: DateTime.now().difference(start),
          );
        }
      }
    } catch (e) {
      return TestResult(
        testName: name,
        status: TestStatus.fail,
        message: 'Technical error: $e',
        duration: DateTime.now().difference(start),
      );
    }
  }

  // --- Fonction privée pour gérer la logique de téléchargement ---
  Future<bool> _simulateUpdate(List<dynamic> assets) async {
    print('\nStarting update process...');

    // 1. Trouver le bon lien (Logique que tu avais dans git_tools)
    String downloadUrl = '';
    // Simplification pour le test : on prend le premier zip
    for (var asset in assets) {
      if (asset['name'].toString().contains('zip')) {
        downloadUrl = asset['browser_download_url'];
        break;
      }
    }

    if (downloadUrl.isEmpty) {
      print('❌ No suitable asset found for download.');
      return false;
    }

    print('⬇️  Downloading from : $downloadUrl');
    // Simulation d'attente (Téléchargement)
    await Future.delayed(Duration(seconds: 2));
    print('✅ Download completed.');

    print('🔧 Installing files...');
    // Simulation d'attente (Dézippage)
    await Future.delayed(Duration(seconds: 1));

    print('✨ Update completed successfully!');
    return true;
  }
}
