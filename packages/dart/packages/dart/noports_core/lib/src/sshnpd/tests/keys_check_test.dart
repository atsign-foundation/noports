import 'dart:io'; 
import '../diagnostic_test.dart';
import '../utils/platform_utils.dart';

class KeysCheckTest extends DiagnosticTest {
  @override
  String get name => 'Keys Check (.atKeys)';

  @override
  String get description =>
      'Checks for the presence of keys directory and .atKeys files';

  @override
  Future<TestResult> run() async {
    final start = DateTime.now();

    // 1. Trouver le dossier HOME de l'utilisateur via PlatformUtils
    String home = PlatformUtils.instance.homeDirectory;
    
    // 2. Construire le chemin standard
    // On utilise le séparateur de l'OS
    String keysPath = '$home${Platform.pathSeparator}.atsign${Platform.pathSeparator}keys';
    var directory = Directory(keysPath);

    // 3. Vérifier si le DOSSIER existe
    if (!await directory.exists()) {
      return TestResult(
        testName: name,
        status: TestStatus.fail,
        message:
            'The keys directory is not found ($keysPath). Have you onboarded your atSign?',
        duration: DateTime.now().difference(start),
      );
    }

    // 4. Vérifier le CONTENU du dossier
    try {
      // On liste les fichiers et on ne garde que ceux qui finissent par ".atKeys"
      List<FileSystemEntity> files = directory.listSync();
      var keyFiles =
          files.where((file) => file.path.endsWith('.atKeys')).toList();

      if (keyFiles.isNotEmpty) {
        // Succès : On a trouvé des clés !
        // On crée une liste propre des noms de fichiers trouvés pour l'info
        var keyNames = keyFiles.map((f) => f.uri.pathSegments.last).join(', ');

        return TestResult(
          testName: name,
          status: TestStatus.pass,
          message:
              'Directory valid. Found ${keyFiles.length} key file(s): $keyNames',
          duration: DateTime.now().difference(start),
        );
      } else {
        // Le dossier est là, mais il est vide (ou pas de .atKeys)
        return TestResult(
          testName: name,
          status: TestStatus.warning,
          message: 'The keys directory exists but contains no .atKeys files.',
          duration: DateTime.now().difference(start),
        );
      }
    } catch (e) {
      return TestResult(
        testName: name,
        status: TestStatus.fail,
        message: 'Error reading the keys directory: $e',
        duration: DateTime.now().difference(start),
      );
    }
  }
}
