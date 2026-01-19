import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/admin_v2.dart';

late AtSignLogger logger;

Future<void> main(List<String> args) async {
  logger = AtSignLogger('  policy_cli  ');

  final PolicyCLIParams policyCLIParams = PolicyCLIParams.fromArgs(args);
  AtSignLogger.root_level = 'severe';
  if (policyCLIParams.verbose) {
    AtSignLogger.root_level = 'info';
  }
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
    baseNameSpace: policyCLIParams.baseNamespace,
    domainNameSpace: 'policy_v2',
  );

  final PolicyClient policyClient = 
  PolicyClient.fromAtRpcClient(atRpcClient: atRpcClient);


  while(true) {
  printMenu();
  print('Enter option:');
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
    case '2': { // getAllClientGroups
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
      print('Enter client name:\n');
      final String? clientName = stdin.readLineSync();
      if(clientName == null || clientName.isEmpty) {
        print('Invalid client name: $clientName');
        break;
      }
      print('Enter client atSign:\n');
      final String? clientAtSign = stdin.readLineSync();
      if(clientAtSign == null || clientAtSign.isEmpty) {
        print('Invalid client atSign: $clientAtSign');
        break;
      }
      final String clientId = await policyClient.putClient(Client(
          name: clientName,
          atSign: clientAtSign));
      print('Put client with generated id: $clientId');
      // final Set<Client> allClients = await policyClient.getAllClients();
      // print('Obtained ${allClients.length} clients:');
      // for(int i = 0; i < allClients.length; i++) {
      //   final Client client = allClients.elementAt(i);
      //   print('[$i]: client.name: ${client.name} | client.atSign: ${client.atSign}');
      // }
      break;
    }
    case '8': { // putClientGroup
      print('Enter client group name (e.g. "RDP Users"):\n');
      final String? clientGroupName = stdin.readLineSync();
      if(clientGroupName == null || clientGroupName.isEmpty) {
        print('Invalid client group name: $clientGroupName');
        break;
      }
      print('Confirm creation of ClientGroup:');
      print('ClientGroup.name: $clientGroupName');
      print('Enter \'y\' to confirm, any other key to cancel:\n');
      final String? confirm = stdin.readLineSync();
      if(confirm == null || confirm.toLowerCase() != 'y') {
        print('Cancelled creation of ClientGroup');
        break;
      }
      final String clientGroupId = await policyClient.putClientGroup(ClientGroup(
        name: clientGroupName));
      print('Put client group with generated id: $clientGroupId');
      break;
    }
    case '9': { // putClientGroupMember
      print('Enter client group id:\n');
      final String? clientGroupId = stdin.readLineSync();
      if(clientGroupId == null || clientGroupId.isEmpty) {
        print('Invalid client group id: $clientGroupId');
        break;
      }
      print('Enter client id:\n');
      final String? clientId = stdin.readLineSync();
      if(clientId == null || clientId.isEmpty) {
        print('Invalid client id: $clientId');
        break;
      }
      print('Confirm creation of ClientGroupMember:');
      print('ClientGroupMember.clientGroupId: $clientGroupId');
      print('ClientGroupMember.clientId: $clientId');
      print('Enter \'y\' to confirm, any other key to cancel:\n');
      final String? confirm = stdin.readLineSync();
      if(confirm == null || confirm.toLowerCase() != 'y') {
        print('Cancelled creation of ClientGroupMember');
        break;
      }
      final String clientGroupMemberId = await policyClient.putClientGroupMember(ClientGroupMember(
        clientGroupId: clientGroupId,
        clientId: clientId));
      print('Put client group member with generated id: $clientGroupMemberId');
      break;
    }
    case '10': { // putDaemon
      print('Enter daemon atSign:\n');
      final String? daemonAtSign = stdin.readLineSync();
      if(daemonAtSign == null || daemonAtSign.isEmpty) {
        print('Invalid daemon atSign: $daemonAtSign');
        break;
      }
      print('Confirm creation of Daemon:');
      print('Daemon.atSign: $daemonAtSign');
      print('Enter \'y\' to confirm, any other key to cancel:\n');
      final String? confirm = stdin.readLineSync();
      if(confirm == null || confirm.toLowerCase() != 'y') {
        print('Cancelled creation of Daemon');
        break;
      }
      final String daemonId = await policyClient.putDaemon(Daemon(
        atSign: daemonAtSign));
      print('Put daemon with generated id: $daemonId');
      break;
    }
    case '11': { // putService
      print('Enter daemon id:\n');
      final String? daemonId = stdin.readLineSync();
      if(daemonId == null || daemonId.isEmpty) {
        print('Invalid daemon id: $daemonId');
        break;
      }
      print('Enter device name (press Enter to default to "default"):\n');
      String? deviceName = stdin.readLineSync();
      if(deviceName == null) {
        print('Invalid device name: $deviceName');
        break;
      }
      if(deviceName.isEmpty) {
        deviceName = 'default';
      }
      print('Enter device group name (press Enter to default to "__none__"):\n');
      String? deviceGroupName = stdin.readLineSync();
      if(deviceGroupName == null) {
        print('Invalid device group name: $deviceGroupName');
        break;
      }
      if(deviceGroupName.isEmpty) {
        deviceGroupName = '__none__';
      }
      print('Confirm creation of Service:');
      print('Service.daemonId: $daemonId');
      print('Service.deviceName: $deviceName');
      print('Service.deviceGroupName: $deviceGroupName');
      print('Enter \'y\' to confirm, any other key to cancel:\n');
      final String? confirm = stdin.readLineSync();
      if(confirm == null || confirm.toLowerCase() != 'y') {
        print('Cancelled creation of Service');
        break;
      }
      final String serviceId = await policyClient.putService(Service(
        daemonId: daemonId,
        deviceName: deviceName,
        deviceGroupName: deviceGroupName));
      print('Put service with generated id: $serviceId');
      break;
    }
    case '12': { // putServiceACL
      print('Enter service id:\n');
      final String? serviceId = stdin.readLineSync(); 
      if(serviceId == null || serviceId.isEmpty) {
        print('Invalid service id: $serviceId');
        break;
      }
      print('Enter client group id:\n');
      final String? clientGroupId = stdin.readLineSync();
      if(clientGroupId == null || clientGroupId.isEmpty) {
        print('Invalid client group id: $clientGroupId');
        break;
      }
      print('Enter permit open (e.g. "localhost:22"):\n');
      final String? permitOpen = stdin.readLineSync();
      if(permitOpen == null || permitOpen.isEmpty) {
        print('Invalid permit open: $permitOpen');
        break;
      }
      print('Confirm creation of ServiceACL:');
      print('ServiceACL.serviceId: $serviceId');
      print('ServiceACL.clientGroupId: $clientGroupId');
      print('ServiceACL.permitOpen: $permitOpen');
      print('Enter \'y\' to confirm, any other key to cancel:\n');
      final String? confirm = stdin.readLineSync();
      if(confirm == null || confirm.toLowerCase() != 'y') {
        print('Cancelled creation of ServiceACL');
        break;
      }
      final String serviceACLId = await policyClient.putServiceACL(ServiceACL(
        serviceId: serviceId,
        clientGroupId: clientGroupId,
        permitOpen: permitOpen));
      print('Put service ACL with generated id: $serviceACLId');
      break;
    }
    default: {
      print('Invalid option $option');
      break;
    }
  }
  print('');
}
}

void printMenu() {
  print('Policy CLI:');
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
