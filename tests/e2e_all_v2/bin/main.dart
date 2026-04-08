import 'dart:async';
import 'dart:io';
import 'package:e2e_all_v2/client_binary.dart';
import 'package:e2e_all_v2/docker_image.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';
import 'package:e2e_all_v2/apkam_setup.dart';
import 'package:e2e_all_v2/language.dart';
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
  print('');
  _printLoadedParameters(e2eAllV2Params);
  print('');

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
    print('\ntestRunId: $testRunId\n');

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
    });
    clientBinaryTuples.add((Language.dart, 'current', ClientBinaryType.at_activate));

    print('Fetching ${clientBinaryTuples.length} client binaries...');
    List<ClientBinary> clientBinaries = await fetchClientBinaries(
      clientBinaryTuples: clientBinaryTuples, 
      binariesDirectory: binariesDirectory);

    print('');
    print('Fetched client binaries (${clientBinaries.length}):');
    for(final ClientBinary clientBinary in clientBinaries) {
      print('    ${clientBinary.binaryType.name} | ${clientBinary.language.name} | ${clientBinary.version} | ${clientBinary.file.path}');
    }
    print('');

    // 6. set up client and daemon apkam keys
    final ClientBinary atActivateClientBinary = clientBinaries.firstWhere((cb) => cb.binaryType == ClientBinaryType.at_activate && cb.version == 'current');
    await setUpApkamKeys(
      atActivateClientBinary: atActivateClientBinary,
      clientAtsign: e2eAllV2Params.clientAtsign,
      daemonAtsign: e2eAllV2Params.daemonAtsign,
      rootDomain: e2eAllV2Params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId
    );

    // 7. set up docker daemons
    final List<Process> dockerInstanceProcesses = await startDockerDaemons(
      daemonVersions: daemonVersions,
      daemonAtsign: e2eAllV2Params.daemonAtsign,
      rootDomain: e2eAllV2Params.rootDomain,
      testRunId: testRunId,
    );
    print('Started ${dockerInstanceProcesses.length} docker daemon instances');
    exit(0);
  } catch (e) {
    print(e);
    exit(1);
  }
}

void _printLoadedParameters(E2EAllV2Params e2eAllV2Params) {
  print('e2e_all_v2 Loaded Parameters:');
  print('    help: ${e2eAllV2Params.help}');
  print('    client-atsign: ${e2eAllV2Params.clientAtsign}');
  print('    daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  print('    relay-atsign: ${e2eAllV2Params.relayAtsign}');
  print('    policy-atsign: ${e2eAllV2Params.policyAtsign}');
  print('    events-atsign: ${e2eAllV2Params.eventsAtsign}');
  print('    root-domain: ${e2eAllV2Params.rootDomain}');
  print('    verbose: ${e2eAllV2Params.verbose}');
  print('    base-directory: ${e2eAllV2Params.baseDirectory}');
}
