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
      break;
    }
    case '2': { // getAllCleintGroups
      final Set<ClientGroup> allClientGroups = await policyClient.getAllClientGroups();
      print('Obtained ${allClientGroups.length} client groups:');
      for(int i = 0; i < allClientGroups.length; i++) {
        final ClientGroup clientGroup = allClientGroups.elementAt(i);
        print('[$i]: clientGroup.id: ${clientGroup.id} | '
          'clientGroup.name: ${clientGroup.name}');
      }
      break;
    }
    case '3': { // getAllClientGroupMembers
      final Set<ClientGroupMember> allClientGroupMembers = await policyClient.getAllClientGroupMembers();
      print('Obtained ${allClientGroupMembers.length} client group members:');
      for(int i = 0; i < allClientGroupMembers.length; i++) {
        final ClientGroupMember clientGroupMember = allClientGroupMembers.elementAt(i);
        print('[$i]: clientGroupMember.id: ${clientGroupMember.id} | '
          'clientGroupId ${clientGroupMember.clientGroupId} | '
          'clientGroupMember.clientId: ${clientGroupMember.clientId}');
      }
      break;
    }
    case '4': { // getAllDaemons
      final Set<Daemon> allDaemons = await policyClient.getAllDaemons();
      print('Obtained ${allDaemons.length} daemons:');
      for(int i = 0; i < allDaemons.length; i++) {
        final Daemon daemon = allDaemons.elementAt(i);
        print('[$i]: daemon.id: ${daemon.id} | daemon.atSign: ${daemon.atSign}');
      }
      break;
    }
    case '5': { // getAllServices
      final Set<Service> allServices = await policyClient.getAllServices();
      print('Obtained ${allServices.length} services:');
      for(int i = 0; i < allServices.length; i++) {
        final Service service = allServices.elementAt(i);
        print('[$i]: service.id: ${service.id} | '
          'service.deviceName: ${service.deviceName} | '
          'service.daemonId: ${service.daemonId}');
      }
      break;
    }
    case '6': { // getAllServiceACLs
      final Set<ServiceACL> allServiceACLs = await policyClient.getAllServiceACLs();
      print('Obtained ${allServiceACLs.length} service ACLs:');
      for(int i = 0; i < allServiceACLs.length; i++) {
        final ServiceACL serviceACL = allServiceACLs.elementAt(i);
        print('[$i]: serviceACL.id: ${serviceACL.id} | '
          'serviceACL.serviceId: ${serviceACL.serviceId} | '
          'serviceACL.clientGroupId: ${serviceACL.clientGroupId} | '
          'serviceACL.permitOpen: ${serviceACL.permitOpen}');
      }
      break;
    }
    case '7': { // putClient
      print('Enter client name: \n');
      final String? clientName = stdin.readLineSync();
      if(clientName == null || clientName.isEmpty) {
        print('Invalid client name: $clientName');
      }
      print('Enter client atSign: \n');
      final String? clientAtSign = stdin.readLineSync();
      if(clientAtSign == null || clientAtSign.isEmpty) {
        print('Invalid client atSign: $clientAtSign');
      }
      final Client client = Client(name: clientName!, atSign: clientAtSign!);
      final String clientId = await policyClient.putClient(client);
      print('Put client with generated id: $clientId');

      final Set<Client> allClients = await policyClient.getAllClients();
      print('Obtained ${allClients.length} clients:');
      for(int i = 0; i < allClients.length; i++) {
        final Client client = allClients.elementAt(i);
        print('[$i]: client.name: ${client.name} | client.atSign: ${client.atSign}');
      }
      break;
    }
    case '8': { // putClientGroup
      break;
    }
    case '9': { // putClientGroupMember
      break;
    }
    case '10': { // putDaemon
      break;
    }
    case '11': { // putService
      break;
    }
    case '12': { // putServiceACL
      break;
    }
    default: {
      print('Invalid option $option');
      break;
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

  if(policyCLIParams.storagePath != null) {
    atOnboardingPreference.hiveStoragePath = policyCLIParams.storagePath;
  }

  return atOnboardingPreference;
}
