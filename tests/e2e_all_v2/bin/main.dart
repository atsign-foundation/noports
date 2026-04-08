import 'dart:async';
import 'dart:io';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/core_test_cases.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/docker_instance.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';
import 'package:e2e_all_v2/utils.dart';

Future<void> main(List<String> args) async {
  // 1. parse args
  E2EAllV2Params e2eAllV2Params;
  try {
    e2eAllV2Params = E2EAllV2Params.parse(args);
    if(e2eAllV2Params.help) {
      E2EAllV2Params.printUsage();
      exit(1);
    }
  } catch(e) {
    E2EAllV2Params.printUsage();
    exit(1);
  }
  _logLoadedParameters(e2eAllV2Params);

  // 2. declare const variables
  const List<String> clientVersions = [
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
    'd:current',
  ];

  const List<String> daemonVersions = [
    'd:current',
    'c:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];

  try {
    // 3. $testRunId = git rev-parse --short HEAD (shortened git commit hash)
    final String testRunId = await getShortenedGitCommitHash();
    print('testRunId: $testRunId');

    // 4. create directory structure: 
    //  ./e2e_all_v2/$testRunId/
    //    ├── apkamKeys/
    //    ├── logs/
    //    └── binaries/
    //            v5.9.4/
    //            v5.11.2/
    //            v5.13.0/
    //            current/
    final Directory baseDirectory = Directory('${e2eAllV2Params.baseDirectory}/$testRunId');
    ensureDirectoryExists(baseDirectory);

    final Directory apkamKeysDirectory = Directory('${baseDirectory.path}/apkamKeys');
    final Directory logsDirectory = Directory('${baseDirectory.path}/logs');
    final Directory binariesDirectory = Directory('${baseDirectory.path}/binaries');
    ensureDirectoryExists(apkamKeysDirectory);
    ensureDirectoryExists(logsDirectory);
    ensureDirectoryExists(binariesDirectory);

    // 5. download client binaries
    List<(Language, String, ClientBinaryType)> clientBinaryTuples = [];
    clientVersions.forEach((languageVersionStr) {
      final Language language = getLanguage(languageVersionStr);
      final String version = getVersionStr(languageVersionStr);
      clientBinaryTuples.add((language, version, ClientBinaryType.sshnp));
      clientBinaryTuples.add((language, version, ClientBinaryType.srv));
      clientBinaryTuples.add((language, version, ClientBinaryType.npt));
      clientBinaryTuples.add((language, version, ClientBinaryType.npp_client));
    });
    clientBinaryTuples.add((Language.dart, 'current', ClientBinaryType.at_activate));
    List<ClientBinary> clientBinaries = await fetchClientBinaries(
      clientBinaryTuples: clientBinaryTuples, 
      binariesDirectory: binariesDirectory);

    final int exitCode = await runCoreTestCases(
      testRunId: testRunId,
      clientAtsign: e2eAllV2Params.clientAtsign,
      daemonAtsign: e2eAllV2Params.daemonAtsign,
      relayAtsign: e2eAllV2Params.relayAtsign,
      rootDomain: e2eAllV2Params.rootDomain,
      atKeysVolumeMapping: VolumeMapping(
        localDirectory: Directory('${baseDirectory.path}/apkamKeys'),
        containerDirectory: Directory('/atsign/.atsign/keys'),
      ),
      baseDirectory: baseDirectory,
    );
    exit(exitCode);
  } catch (e) {
    exit(1);
  }
}

void _logLoadedParameters(E2EAllV2Params e2eAllV2Params) {
  print('e2e_all_v2 Loaded Parameters:');
  print('  help: ${e2eAllV2Params.help}');
  print('  client-atsign: ${e2eAllV2Params.clientAtsign}');
  print('  daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  print('  relay-atsign: ${e2eAllV2Params.relayAtsign}');
  print('  policy-atsign: ${e2eAllV2Params.policyAtsign}');
  print('  events-atsign: ${e2eAllV2Params.eventsAtsign}');
  print('  root-domain: ${e2eAllV2Params.rootDomain}');
  print('  verbose: ${e2eAllV2Params.verbose}');
  print('  base-directory: ${e2eAllV2Params.baseDirectory}');
}
