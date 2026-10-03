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
  String get description => 'Checks if a new version of sshnpd is available';

  @override
  Future<CheckResult> run(Map<String, dynamic> context) async {
    final start = DateTime.now();
    Version currentVersion = packageVersion;

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

        // Check if sshnpd was installed via a package manager
        String? packageManagerCmd = await PlatformUtils.instance
            .detectPackageManagerInstall('noports');

        if (packageManagerCmd != null) {
          return CheckResult(
            checkName: name,
            status: CheckStatus.warning,
            message:
                'Update available ($currentVersion → $cleanLatest). '
                'Installed via package manager — run: $packageManagerCmd',
            duration: DateTime.now().difference(start),
          );
        }

        // Not installed via a package manager — advise platform-specific install
        String advice = await PlatformUtils.instance
            .getRecommendedInstallAdvice('noports');
        print('\n $advice\n');
        return CheckResult(
          checkName: name,
          status: CheckStatus.warning,
          message: 'Update available ($currentVersion → $cleanLatest). $advice',
          duration: DateTime.now().difference(start),
        );
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
}
