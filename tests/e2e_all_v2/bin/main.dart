import 'dart:io';
import 'package:at_utils/at_utils.dart';
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
}

void _logLoadedParameters(E2EAllV2Params e2eAllV2Params) {
  logger.info('e2e_all_v2 Loaded Parameters:');
  logger.info('  help: ${e2eAllV2Params.help}');
  logger.info('  client-atsign: ${e2eAllV2Params.clientAtsign}');
  logger.info('  daemon-atsign: ${e2eAllV2Params.daemonAtsign}');
  logger.info('  relay-atsign: ${e2eAllV2Params.relayAtsign}');
  logger.info('  relay-latest-atsign: ${e2eAllV2Params.relayLatestAtsign}');
  logger.info('  policy-atsign: ${e2eAllV2Params.policyAtsign}');
  logger.info('  policy-latest-atsign: ${e2eAllV2Params.policyLatestAtsign}');
  logger.info('  events-atsign: ${e2eAllV2Params.eventsAtsign}');
  logger.info('  root-domain: ${e2eAllV2Params.rootDomain}');
  logger.info('  verbose: ${e2eAllV2Params.verbose}');
}
