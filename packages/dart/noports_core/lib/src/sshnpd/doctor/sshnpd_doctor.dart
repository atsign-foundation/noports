import 'dart:io';
import 'package:noports_core/src/sshnpd/sshnpd_config.dart';
import 'package:noports_core/src/sshnpd/doctor/diagnostic_runner.dart';
import 'package:noports_core/src/sshnpd/doctor/utils/platform_utils.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/keys_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/prerequisites_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/service_status_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/config_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/version_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/service_logs_check.dart';
import 'package:noports_core/src/sshnpd/doctor/checks/connectivity_check.dart';

class SshnpdDoctor {
  Future<void> run(List<String> args, {required String packageVersion}) async {

    print('-' * 60) ;
    print('Welcome to the SSHNPD Doctor - Diagnostic Tool');
    print('-' * 60);
    print('');

    final runner = DiagnosticRunner(
      verbose: true,
      checks: [
        PrerequisitesCheck(), 
        ConnectivityCheck(), 
        KeysCheck(), 
        ServiceStatusCheck(), 
        ServiceLogsCheck(), 
        ConfigCheck(), 
        VersionCheck(packageVersion), 
      ],
    );
    final results = await runner.runAll();

    String summary = runner.generateSummary(results);

    final platform = PlatformUtils.instance;
    final os = platform.name;
    final arch = await platform.getArchitecture();
    final version = VersionCheck(packageVersion).packageVersion;
    final home = platform.homeDirectory;
    final keysPath =                             '$home${Platform.pathSeparator}.atsign${Platform.pathSeparator}keys';

    final systemInfo = '''
${'-' * 60}
SYSTEM INFORMATION
${'-' * 60}
Platform     : $os
Architecture : $arch
Version      : $version
Home Dir     : $home
Keys Path    : $keysPath
${'-' * 60}
''';

    summary = systemInfo + summary;

    print(summary);
    try {
      final results = SshnpdOption.argParser.parse(args);
      if (results['output'] == true) {
        String outputName = 'sshnpd_doctor_log.txt';
        if (results.rest.isNotEmpty) {
          outputName = results.rest.first;
        }
        final file = File(outputName);
        await file.writeAsString(summary);
        print('Summary saved to $outputName');
      }
    } catch (e) {
      // Ignore error if parsing fails
    }
  }
}
