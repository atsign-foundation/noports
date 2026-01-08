import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:noports_core/admin_v2.dart';

Future<void> main(List<String> args) async {
  final PolicyCLIParams policyCLIParams = PolicyCLIParams.fromArgs(args);
  final AtOnboardingPreference atOnboardingPreference = generateAtOnboardingPreference(policyCLIParams);
  final AtOnboardingService atOnboardingService = AtOnboardingServiceImpl(policyCLIParams.atSign, atOnboardingPreference);
  final bool authSuccess = await atOnboardingService.authenticate();
  if(!authSuccess) {
    print('Auth Success: $authSuccess');
    return;
  }

  final AtClient atClient = atOnboardingService.atClient!;

  final AtRpcClient atRpcClient = AtRpcClient(
    atClient: atClient,
    serverAtsign: policyCLIParams.policyAtSign,
    baseNameSpace: policyCLIParams.namespace,
    domainNameSpace: 'policy');

  final PolicyClient policyClient =
  PolicyClient.fromAtRpcClient(atRpcClient: atRpcClient);

  while(true) {
  printHelpMessage();
  print('Enter option: \n');
  final String? option = stdin.readLineSync();
  if(option == null) {
      throw Exception('$option is null'); 
    }
  switch(option) {
    case '1': { // getAllClients
      final Set<Client> allClients = await policyClient.getAllClients();
      print('Obtained ${allClients.length} clients:');
      for(int i = 0; i < allClients.length; i++) {
        final Client client = allClients.elementAt(i);
        print('[$i]: client.name: ${client.name} | client.atSign: ${client.atSign}');
      }
    }
    case '2': { // getAllCleintGroups
      // final Set<ClientGroup> allClientGroups = await policyClient.getAllClientGroups();

    }
  }
}
}

void printHelpMessage() {
  print('1. getAllClients');
  print('2. getAllClientGroups');
  print('3. getAllClientGroupMembers');
  print('4. getAllDaemons');
  print('5. getAllServices');
  print('6. getAllServiceACLs');
  print('7. putClient');
  print('8. putClientGroup');
  print('9. putClientGroupMember');
  print('10. putDaemon');
  print('11. putService');
  print('12. putServiceACL');
}

AtOnboardingPreference generateAtOnboardingPreference(
  PolicyCLIParams policyCLIParams
) {
  final AtOnboardingPreference atOnboardingPreference = AtOnboardingPreference()
  ..rootDomain = policyCLIParams.rootServer.split(':')[0]
  ..rootPort = int.parse(policyCLIParams.rootServer.split(':')[1])
  ..atKeysFilePath = policyCLIParams.atKeysFilePath;

  return atOnboardingPreference;
}
