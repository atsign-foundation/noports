import 'dart:async';
import 'dart:io';
import 'package:at_utils/at_utils.dart';
import 'package:e2e_all_v2/docker_manager.dart';
import 'package:e2e_all_v2/e2e_all_v2_params.dart';

late AtSignLogger logger;

Future<void> main(List<String> args) async {
  logger = AtSignLogger('e2e_all_v2');
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

  v4_dart_inline();
}

void test_minus_r_flag() {

}

void test_minus_u_flag() {

}

void npt_to_port_22() {
}

void npt_to_port_22_no_encrypt_traffic() {
}

Future<int> v4_dart_inline() async {
  const List<String> clientVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];
  const List<String> daemonVersions = [
    'd:current',
    'd:v5.9.4',
    'd:v5.11.2',
    'd:v5.13.0',
  ];
  List<(String, String)> testCases = [];
  for(final String clientVersion in clientVersions) {
    for(final String daemonVersion in daemonVersions) {
      if(!clientVersion.contains('d:current') && !daemonVersion.contains('d:current')) {
        continue;
      }
      testCases.add((clientVersion, daemonVersion));
    }
  }
  print(testCases);

  for(final (String, String) testCase in testCases) {
    final String clientVersion = testCase.$1;
    final String daemonVersion = testCase.$2;

    Language language;
    final List<String> daemonVersionSplit = daemonVersion.split(':');
    if(daemonVersionSplit.length != 2) {
      print('daemonVersionSplit was expected to be length == 2');
      return 1;
    }
    switch(daemonVersionSplit[0]) {
      case('d'): {
        language = Language.dart;
        break;
      }
      case('c'): {
        language = Language.c;
        break;
      }
      default: {
        print('Could not parse language: ${daemonVersionSplit[0]}');
        return 1;
      }
    }

    final String value = daemonVersionSplit[1];

    DockerImage dockerImage;
    if(value.startsWith('v')) {
      dockerImage = DockerImage.release(language: language, version: value);
    } else if (value == 'current') {
      dockerImage = DockerImage.current(language: language);
    } else {
      dockerImage = DockerImage.branch(language: language, branch: value);
    }

    final Process tryPullProcess = await dockerImage.tryPull();
    
  }
}



void _logLoadedParameters(E2EAllV2Params e2eAllV2Params) {
  logger.info('e2e_all_v2 Loaded Parameters:');
  logger.info('  help: ${e2eAllV2Params.help}');
  logger.info('  client-atsign: ${e2eAllV2Params.clientAtsign}');
  logger.info('  daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  logger.info('  relay-atsign: ${e2eAllV2Params.relayAtsign}');
  logger.info('  policy-atsign: ${e2eAllV2Params.policyAtsign}');
  logger.info('  events-atsign: ${e2eAllV2Params.eventsAtsign}');
  logger.info('  root-domain: ${e2eAllV2Params.rootDomain}');
  logger.info('  verbose: ${e2eAllV2Params.verbose}');
}

// const List<String> clientVersions = [
//   'v5.9.4',
//   'v5.11.2',
//   'v5.13.0',
// ];
//
// const List<String> daemonVerisons = [
//   'v5.9.4',
//   'v5.11.2',
//   'v5.13.0',
// ];
//
// final DockerImage dockerImage = DockerImage.release(language: Language.dart, version: 'v5.9.4');
// final Process dockerImageBuildProcess = await dockerImage.build(forceOverwriteCache: false);
// // dockerImageBuildProcess.stdout.transform(utf8.decoder).listen((event) {
// //   print(event);
// // });
//
// dockerImageBuildProcess.stderr.transform(utf8.decoder).listen((event) {
//   print(event);
// });
//
// final DockerInstance dockerInstance = DockerInstance(dockerImage: dockerImage);
// final Process dockerInstanceProcess = await dockerInstance.run();
// dockerInstanceProcess.stderr.transform(utf8.decoder).listen((event) {
//   print(event);
// });

// Clients: Dart Current, Dart v5.9.4, Dart v5.11.2, Dart v5.13.0
// Daemons: Dart Current, C Current, Dart v5.9.4, Dart v5.11.2, Dart v5.13.0
// Relay: Dart Current
// Policy: Dart Current
// Events: Dart Current

// sudo docker build \
//  -f $dockerfile \
//  -t $tag \
//  --quiet \
//  ?--no-cache \
//  ?--build-arg release=v5.9.4 \
// --target runtime \
// .

// sudo docker run \
//  --rm \
//  -d \
//  --name "$containerName" \
//  -v ~/.atsign/keys/:/atsign/.atsign/keys/ \
//  $TAG
//  /bin/bash -c sudo service ssh start && /usr/local/bin/sshnpd -a @daemon -m @client -d deviceName $daemonFlags --root-domain root-domain -v

// atsigncompany/noports_e2e_all_$type:current
// atsigncompany/noports_e2e_all_$type:vx.x.x
// Base Image: atsigncompany/noports_e2e_all_base_runtime:latest
