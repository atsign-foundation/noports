import 'dart:io';
import 'package:noports_core/src/sshnpd/sshnpd_config.dart';
import 'package:noports_core/src/sshnpd/diagnostic_runner.dart';
import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';
import 'package:noports_core/src/sshnpd/tests/keys_check.dart';
import 'package:noports_core/src/sshnpd/tests/prerequisites_check.dart';
import 'package:noports_core/src/sshnpd/tests/service_status_check.dart';
import 'package:noports_core/src/sshnpd/tests/config_check.dart';
import 'package:noports_core/src/sshnpd/tests/version_check.dart';
import 'package:noports_core/src/sshnpd/tests/service_logs_check.dart';
import 'package:noports_core/src/sshnpd/tests/connectivity_check.dart';

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
  try {
    final results = SshnpdOption.argParser.parse(args);
    if (results.wasParsed('output')) {
      String outputName = 'sshnpd_doctor_log.txt';
      if (results.rest.isNotEmpty) {
        // If there's a remaining argument that looks like a filename, use it
        // We assume the filename would be the next argument if it was intended as such
        // However, with arg parser, rest contains all non-option arguments.
        // If the user typed `sshnpd --doctor -o mylog.txt`, `mylog.txt` will be in rest.
        outputName = results.rest.first;
      }
      final file = File(outputName);
      await file.writeAsString(summary);
      print('Summary saved to $outputName');
    }
  } catch (e) {
    // Ignore error if parsing fails, as it's just for output file
  }
  }
}
