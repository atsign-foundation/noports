import 'dart:io';
import 'dart:convert';
import '../diagnostic_test.dart';
import 'package:sshnoports/src/version.dart' as pkg;
import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';
import 'package:version/version.dart';


class VersionCheck extends DiagnosticTest {

  @override
  String get name => 'Version Check';

  Version get packageVersion => Version.parse(pkg.packageVersion);

  @override
  String get description =>
      'Checks if a new version of sshnpd is available and offers to update';


  @override
  Future<TestResult> run() async {
    final start = DateTime.now();
    Version currentVersion = packageVersion;

    try {
      // Get the latest version from GitHub
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

      Version cleanLatest = Version.parse(latestTag.replaceAll('v', '').trim());
      
      if (cleanLatest <= currentVersion) {
        if (cleanLatest == currentVersion) {
          return TestResult(
            testName: name,
            status: TestStatus.pass,
            message: 'Software is up to date (v$currentVersion).',
            duration: DateTime.now().difference(start),
          );
        } else {
          return TestResult(
            testName: name,
            status: TestStatus.warning,
            message: 'Your version is higher than the latest version (v$currentVersion). Please consider downgrading to an official release.',
            duration: DateTime.now().difference(start),
          );
        }
      } else {
        // Interaction
        String os = Platform.operatingSystem;
        String arch = await PlatformUtils.instance.getArchitecture();

        print('\n A NEW UPDATE IS AVAILABLE !');
        print('    Current version: $currentVersion');
        print('   New version: $cleanLatest');
        print('Detected OS: $os');
        print('Detected Architecture: $arch');
        print('If OS or Architecture is not correct, please download the update manually');
        stdout.write('Do you want to download the update now? (y/n) : ');

        String? answer = stdin.readLineSync();

        if (answer != null && answer.toLowerCase().startsWith('y')) {
          
          String extension = (Platform.isWindows || Platform.isMacOS) ? 'zip' : 'tgz';
          
          // Construct expected asset name pattern, e.g., sshnp-macos-arm64.zip
          String expectedAssetStart = 'sshnp-$os-$arch';
          
          print(' Looking for asset matching: $expectedAssetStart...$extension');

          Map<String, dynamic>? targetAsset;
          
          for (var asset in data['assets']) {
            String assetName = asset['name'].toString();
            if (assetName.startsWith(expectedAssetStart) && assetName.endsWith(extension)) {
              targetAsset = asset;
              break;
            }
          }
          
          if (targetAsset == null) {
             print(' No suitable asset found for your system ($os $arch).');
             print(' Please check manually at: https://github.com/atsign-foundation/noports/releases/latest');
             return TestResult(
               testName: name,
               status: TestStatus.warning, 
               message: 'Automatic update not available for $os-$arch.',
               duration: DateTime.now().difference(start),
             );
          }

          // Lancer le téléchargement
          bool success = await _performUpdate(targetAsset['browser_download_url'], targetAsset['name']);

          if (success) {
            return TestResult(
              testName: name,
              status: TestStatus.pass,
              message: 'Update downloaded successfully.',
              duration: DateTime.now().difference(start),
            );
          } else {
            return TestResult(
              testName: name,
              status: TestStatus.fail,
              message: 'Download failed. Please try manually.',
              duration: DateTime.now().difference(start),
            );
          }
        } else {
          return TestResult(
            testName: name,
            status: TestStatus.warning,
            message: 'Update ignored by user (v$currentVersion).',
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

  // Function to download the update
  Future<bool> _performUpdate(String downloadUrl, String fileName) async {
    print('\n⬇️  Downloading $fileName from GitHub...');
    
    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        print(' Download failed with status code: ${response.statusCode}');
        return false;
      }

      String path = '${Directory.current.path}/$fileName';
      final file = File(path);
      var sink = file.openWrite();
      
      await response.pipe(sink); // Pipe closes the sink
      
      print(' Download completed: $path');
      print(' Please unzip/untar this file and replace your existing binary.');
      print('   Installation requires manual steps properly suited for your specific setup.');
      return true;
    } catch (e) {
      print(' Download error: $e');
      return false;
    }
  }
}

