import 'dart:io';
import 'dart:convert';
import '../diagnostic_check.dart';
import '../utils/platform_utils.dart';
import 'package:version/version.dart';

class VersionCheck extends DiagnosticCheck {
  @override
  String get name => 'Version Check';

  final String packageVersionString;

  VersionCheck(this.packageVersionString);

  Version get packageVersion => Version.parse(packageVersionString);

  @override
  String get description =>
      'Checks if a new version of sshnpd is available and offers to update';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async {
    final start = DateTime.now();
    Version currentVersion = Version.parse(
      '5.0.0',
    ); // Default to 5.0.0 if parsing fails

    try {
      var result = await Process.run('curl', [
        '-s',
        'https://api.github.com/repos/atsign-foundation/noports/releases/latest',
      ]);

      if (result.exitCode != 0) {
        return CheckResult(
          checkName: name,
          status: CheckStatus.warning,
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
          return CheckResult(
            checkName: name,
            status: CheckStatus.pass,
            message:
                'Software is up to date (current version: $currentVersion).',
            duration: DateTime.now().difference(start),
          );
        } else {
          return CheckResult(
            checkName: name,
            status: CheckStatus.warning,
            message:
                'Your version is higher than the latest version (current version: $currentVersion, latest version: $cleanLatest). Please consider downgrading to an official release.',
            duration: DateTime.now().difference(start),
          );
        }
      } else {
        // A newer version is available
        print('\n A NEW UPDATE IS AVAILABLE!');
        print('Current version: $currentVersion');
        print('New version: $cleanLatest');

        // Check if sshnpd was installed via a package manager
        String? packageManagerCmd =
            await PlatformUtils.instance.detectPackageManagerInstall('sshnpd');

        if (packageManagerCmd != null) {
          print(
            '\n sshnpd appears to have been installed via a package manager.',
          );
          print(' Please update using your package manager:');
          print('\n   $packageManagerCmd\n');
          return CheckResult(
            checkName: name,
            status: CheckStatus.warning,
            message:
                'Update available ($currentVersion → $cleanLatest). '
                'Installed via package manager — run: $packageManagerCmd',
            duration: DateTime.now().difference(start),
          );
        }

        // Not installed via a package manager — offer binary update
        stdout.write('Do you want to download the update now? (y/n) : ');

        String? answer = stdin.readLineSync();

        if (answer != null && answer.toLowerCase().startsWith('y')) {
          // Find the universal.sh asset from the release
          Map<String, dynamic>? targetAsset;

          for (var asset in data['assets']) {
            String assetName = asset['name'].toString();
            if (assetName == 'universal.sh') {
              targetAsset = asset;
              break;
            }
          }

          if (targetAsset == null) {
            print(' universal.sh not found in the release assets.');
            print(
              ' Please check manually at: https://github.com/atsign-foundation/noports/releases/latest',
            );
            return CheckResult(
              checkName: name,
              status: CheckStatus.warning,
              message:
                  'Automatic update not available: universal.sh not found in the release.',
              duration: DateTime.now().difference(start),
            );
          }

          // Start the download
          bool success = await _performUpdate(
            targetAsset['browser_download_url'],
            targetAsset['name'],
          );

          if (success) {
            return CheckResult(
              checkName: name,
              status: CheckStatus.pass,
              message: 'Update downloaded successfully.',
              duration: DateTime.now().difference(start),
            );
          } else {
            return CheckResult(
              checkName: name,
              status: CheckStatus.fail,
              message: 'Download failed. Please try manually.',
              duration: DateTime.now().difference(start),
            );
          }
        } else {
          return CheckResult(
            checkName: name,
            status: CheckStatus.warning,
            message: 'Update ignored by user (v$currentVersion).',
            duration: DateTime.now().difference(start),
          );
        }
      }
    } catch (e) {
      return CheckResult(
        checkName: name,
        status: CheckStatus.fail,
        message: 'Technical error: $e',
        duration: DateTime.now().difference(start),
      );
    }
  }

  // Function to download the update
  Future<bool> _performUpdate(String downloadUrl, String fileName) async {
    print('\n  Downloading $fileName from GitHub...');

    try {
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(Uri.parse(downloadUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        print(' Download failed with status code: ${response.statusCode}');
        return false;
      }

      String path = '${Directory.current.path}/universal.sh';
      final file = File(path);
      var sink = file.openWrite();

      await response.pipe(sink); // Pipe closes the sink

      print(' Download completed: $path');
      await Process.run('chmod', ['+x', path]);

      // universal.sh uses `set -eu` then reads $SUDO_USER in parse_env.
      // When running as root directly (not via sudo), SUDO_USER is unset
      // and the script crashes. We need to handle two cases:
      // 1. Already root → inject SUDO_USER into the environment
      // 2. Not root on Linux → run via sudo
      final isRoot = Platform.isLinux &&
          (await Process.run('id', ['-u'])).stdout.toString().trim() == '0';

      String executable;
      List<String> args;
      Map<String, String>? environment;

      if (Platform.isLinux && !isRoot) {
        // Not root: need sudo to run the installer
        executable = 'sudo';
        args = [path];
      } else {
        executable = path;
        args = [];
        if (isRoot && !Platform.environment.containsKey('SUDO_USER')) {
          // Root without sudo: inject SUDO_USER so universal.sh doesn't crash
          environment = Map<String, String>.from(Platform.environment);
          environment['SUDO_USER'] = Platform.environment['USER'] ?? 'root';
        }
      }

      final process = await Process.start(
        executable,
        args,
        mode: ProcessStartMode.inheritStdio,
        environment: environment,
      );
      final exitCode = await process.exitCode;
      if (exitCode == 0) {
        try {
          await Process.run('rm', [path]);
        } catch (e) {
          print(' Warning: Could not remove $path: $e');
        }
        print(' Update completed successfully.');
        return true;
      } else {
        print(' Update failed.');
        return false;
      }
    } catch (e) {
      print(' Download error: $e');
      return false;
    }
  }

}
