import 'dart:io';
import 'package:noports_core/src/sshnpd/diagnostic_runner.dart';
import 'package:noports_core/src/sshnpd/diagnostic_test.dart';
import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';
import 'package:noports_core/src/sshnpd/tests/keys_check_test.dart';
import 'package:noports_core/src/sshnpd/tests/prerequisites_test.dart';
import 'package:noports_core/src/sshnpd/tests/service_status_test.dart';
import 'package:noports_core/src/sshnpd/tests/config_check_test.dart';
import 'package:noports_core/src/sshnpd/tests/version_check_test.dart';
import 'package:noports_core/src/sshnpd/tests/service_logs_test.dart';
import 'package:noports_core/src/sshnpd/tests/connectivity_test.dart';
import 'package:sshnoports/src/version.dart';

class SshnpdDoctor {
  Future<void> run() async {
    
    print('-' * 60) ;
    print('Welcome to the SSHNPD Doctor - Diagnostic Tool');
    print('-' * 60);
    print('');

  final runner = DiagnosticRunner(
    verbose: true,
    tests: [
      PrerequisitesTest(), 
      KeysCheckTest(), 
      ServiceStatusTest(), 
      ServiceLogsTest(), 
      ConfigCheckTest(), 
      VersionCheckTest(), 
    ],
  );
  final results = await runner.runAll();

  String summary = runner.generateSummary(results);

  final platform = PlatformUtils.instance;
  final os = platform.name;
  final arch = await platform.getArchitecture();
  final version = packageVersion;
  final home = platform.homeDirectory;
  final keysPath = '$home${Platform.pathSeparator}.atsign${Platform.pathSeparator}keys';

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
  final file = File('doctor_summary.txt');
  await file.writeAsString(summary);
  print('Summary saved to doctor_summary.txt');
  }
}
