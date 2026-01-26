import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/npp.dart';
import 'package:chalkdart/chalk.dart';
import 'package:cli_menu/cli_menu.dart';
import 'package:sshnoports/src/print_version.dart';

import 'cli_menu_helper.dart';

late AtSignLogger logger;

Future<void> main(List<String> args) async {
  logger = AtSignLogger('  policy_cli  ');

  // Handle --help and --version flags before parsing
  try {
    final argResults = NPPCLIParams.argParser.parse(args);
    if (argResults['help']) {
      print(NPPCLIParams.argParser.usage);
      exit(0);
    }
    if (argResults['version']) {
      printVersion();
      exit(0);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.writeln('\nUsage:');
    stderr.writeln(NPPCLIParams.argParser.usage);
    exit(1);
  } catch (e) {
    // Continue to fromArgs which will handle other errors
  }

  final NPPCLIParams nppCLIParams;
  try {
    nppCLIParams = NPPCLIParams.fromArgs(args);
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.writeln('\nUsage:');
    stderr.writeln(NPPCLIParams.argParser.usage);
    exit(1);
  }
  AtSignLogger.root_level = 'severe';
  if (nppCLIParams.verbose) {
    AtSignLogger.root_level = 'info';
  }
  final AtOnboardingPreference atOnboardingPreference = generateAtOnboardingPreference(nppCLIParams);
  final AtOnboardingService atOnboardingService = AtOnboardingServiceImpl(nppCLIParams.atSign, atOnboardingPreference);
  final bool authSuccess = await atOnboardingService.authenticate();
  if(!authSuccess) {
    print('Auth Success: $authSuccess');
    return;
  }

  final AtClient atClient = atOnboardingService.atClient!;

  final AtRpcClient atRpcClient = AtRpcClient(
    atClient: atClient,
    serverAtsign: nppCLIParams.policyAtSign,
    baseNameSpace: nppCLIParams.baseNamespace,
    domainNameSpace: nppCLIParams.domainNamespace!,
  );

  final PolicyClient policyClient = PolicyClient.fromAtRpcClient(
    atRpcClient: atRpcClient,
    atClient: atClient,
    serverAtSign: nppCLIParams.policyAtSign,
    baseNameSpace: nppCLIParams.baseNamespace,
  );


  while(true) {
  final String option = showMenuAndGetSelection();
  switch(option) {
    case '1': { // ping
      print(chalk.blue('\nSending ping request...'));
      try {
        final Map<String, dynamic> pingResponse = await policyClient.ping();
        print(chalk.green('\n✓ Ping successful!'));
        print('  ${chalk.cyan('status')}: ${pingResponse['status']}');
        if (pingResponse.containsKey('binariesVersion')) {
          print('  ${chalk.cyan('binariesVersion')}: ${pingResponse['binariesVersion']}');
        }
        print('  ${chalk.cyan('coreVersion')}: ${pingResponse['coreVersion']}');
        print('  ${chalk.cyan('features')}: ${(pingResponse['features'] as List).join(', ')}');
        print('  ${chalk.cyan('timestamp')}: ${pingResponse['timestamp']}');
      } catch (e) {
        print(chalk.red('\n✗ Ping failed: $e'));
      }
      break;
    }
    case '2': { // getAllClients
      final Set<Client> allClients = await policyClient.getAllClients();
      print(chalk.green('\n✓ Obtained ${allClients.length} clients:'));
      for(int i = 0; i < allClients.length; i++) {
      final Client client = allClients.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(client.id ?? 'N/A')}) | name: ${client.name} | atSign: ${client.atSign}');
    }
      break;
    }
    case '3': { // getAllClientGroups
      final Set<ClientGroup> allClientGroups = await policyClient.getAllClientGroups();
      print(chalk.green('\n✓ Obtained ${allClientGroups.length} client groups:'));
      for(int i = 0; i < allClientGroups.length; i++) {
      final ClientGroup clientGroup = allClientGroups.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(clientGroup.id ?? 'N/A')}) | '
        'name: ${clientGroup.name}');
    }
      break;
    }
    case '4': { // getAllClientGroupMembers
      final Set<ClientGroupMember> allClientGroupMembers = await policyClient.getAllClientGroupMembers();
      print(chalk.green('\n✓ Obtained ${allClientGroupMembers.length} client group members:'));
      for(int i = 0; i < allClientGroupMembers.length; i++) {
      final ClientGroupMember clientGroupMember = allClientGroupMembers.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(clientGroupMember.id ?? 'N/A')}) | '
        'clientGroupId: (${clientGroupMember.clientGroupId}) | '
        'clientId: (${clientGroupMember.clientId})');
    }
      break;
    }
    case '5': { // getAllDaemons
      final Set<Daemon> allDaemons = await policyClient.getAllDaemons();
      print(chalk.green('\n✓ Obtained ${allDaemons.length} daemons:'));
      for(int i = 0; i < allDaemons.length; i++) {
      final Daemon daemon = allDaemons.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(daemon.id ?? 'N/A')}) | atSign: ${daemon.atSign}');
    }
      break;
    }
    case '6': { // getAllServices
      final Set<Service> allServices = await policyClient.getAllServices();
      print(chalk.green('\n✓ Obtained ${allServices.length} services:'));
      for(int i = 0; i < allServices.length; i++) {
      final Service service = allServices.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(service.id ?? 'N/A')}) | '
        'deviceName: ${service.deviceName} | '
        'daemonId: (${service.daemonId})');
    }
      break;
    }
    case '7': { // getAllServiceACLs
      final Set<ServiceACL> allServiceACLs = await policyClient.getAllServiceACLs();
      print(chalk.green('\n✓ Obtained ${allServiceACLs.length} service ACLs:'));
      for(int i = 0; i < allServiceACLs.length; i++) {
      final ServiceACL serviceACL = allServiceACLs.elementAt(i);
      print('  ${chalk.cyan('[$i]')}: id: (${chalk.yellow(serviceACL.id ?? 'N/A')}) | '
        'serviceId: (${serviceACL.serviceId}) | '
        'clientGroupId: (${serviceACL.clientGroupId}) | '
        'permitOpen: ${serviceACL.permitOpen}');
    }
      break;
    }
    case '8': { // putClient
      stdout.write(chalk.white('\nEnter client name: '));
      final String? clientName = stdin.readLineSync();
      if(clientName == null || clientName.isEmpty) {
        print(chalk.red('Invalid client name: $clientName'));
        break;
      }
      stdout.write(chalk.white('Enter client atSign: '));
      final String? clientAtSign = stdin.readLineSync();
      if(clientAtSign == null || clientAtSign.isEmpty) {
        print(chalk.red('Invalid client atSign: $clientAtSign'));
        break;
      }

      print(chalk.bold.white('\nConfirm creation of Client:'));
      print('  ${chalk.cyan('name')}: $clientName');
      print('  ${chalk.cyan('atSign')}: $clientAtSign');

      final bool confirmed = CliMenuHelper.confirm('Create this Client?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of Client'));
        break;
      }

      final String clientId = await policyClient.putClient(Client(
          name: clientName,
          atSign: clientAtSign));
      print(chalk.green('✓ Put client with generated id: $clientId'));
      break;
    }
    case '9': { // putClientGroup
      stdout.write(chalk.white('\nEnter client group name (e.g. "RDP Users"): '));
      final String? clientGroupName = stdin.readLineSync();
      if(clientGroupName == null || clientGroupName.isEmpty) {
        print(chalk.red('Invalid client group name: $clientGroupName'));
        break;
      }

      print(chalk.bold.white('\nConfirm creation of ClientGroup:'));
      print('  ${chalk.cyan('name')}: $clientGroupName');

      final bool confirmed = CliMenuHelper.confirm('Create this ClientGroup?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of ClientGroup'));
        break;
      }

      final String clientGroupId = await policyClient.putClientGroup(ClientGroup(
        name: clientGroupName));
      print(chalk.green('✓ Put client group with generated id: $clientGroupId'));
      break;
    }
    case '10': { // putClientGroupMember
      print(chalk.blue('Fetching available clients...'));
      final Set<Client> allClients = await policyClient.getAllClients();
      if(allClients.isEmpty) {
        print(chalk.red('No clients found. Please create a client first (option 8).'));
        break;
      }

      final List<Client> clientsList = allClients.toList();
      final String? clientId = await CliMenuHelper.selectClientId(clientsList);
      if(clientId == null || clientId.isEmpty) {
        print(chalk.yellow('Cancelled client selection'));
        break;
      }

      final Client selectedClient = clientsList.firstWhere((c) => c.id == clientId);

      print(chalk.blue('\nFetching available client groups...'));
      final Set<ClientGroup> allClientGroups = await policyClient.getAllClientGroups();
      if(allClientGroups.isEmpty) {
        print(chalk.red('No client groups found. Please create a client group first (option 9).'));
        break;
      }

      final List<ClientGroup> clientGroupsList = allClientGroups.toList();
      final String? clientGroupId = await CliMenuHelper.selectClientGroupId(clientGroupsList);
      if(clientGroupId == null || clientGroupId.isEmpty) {
        print(chalk.yellow('Cancelled client group selection'));
        break;
      }

      final ClientGroup selectedClientGroup = clientGroupsList.firstWhere((cg) => cg.id == clientGroupId);

      print(chalk.bold.white('\nConfirm creation of ClientGroupMember:'));
      print('  ${chalk.cyan('clientId')}: $clientId (${selectedClient.atSign})');
      print('  ${chalk.cyan('clientGroupId')}: $clientGroupId (${selectedClientGroup.name})');

      final bool confirmed = CliMenuHelper.confirm('Add ${selectedClient.atSign} to ${selectedClientGroup.name}?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of ClientGroupMember'));
        break;
      }

      final String clientGroupMemberId = await policyClient.putClientGroupMember(ClientGroupMember(
        clientGroupId: clientGroupId,
        clientId: clientId));
      print(chalk.green('✓ Put client group member with generated id: $clientGroupMemberId'));
      break;
    }
    case '11': { // putDaemon
      stdout.write(chalk.white('\nEnter daemon atSign: '));
      final String? daemonAtSign = stdin.readLineSync();
      if(daemonAtSign == null || daemonAtSign.isEmpty) {
        print(chalk.red('Invalid daemon atSign: $daemonAtSign'));
        break;
      }

      print(chalk.bold.white('\nConfirm creation of Daemon:'));
      print('  ${chalk.cyan('atSign')}: $daemonAtSign');

      final bool confirmed = CliMenuHelper.confirm('Create this Daemon?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of Daemon'));
        break;
      }

      final String daemonId = await policyClient.putDaemon(Daemon(
        atSign: daemonAtSign));
      print(chalk.green('✓ Put daemon with generated id: $daemonId'));
      break;
    }
    case '12': { // putService
      print(chalk.blue('Fetching available daemons...'));
      final Set<Daemon> allDaemons = await policyClient.getAllDaemons();
      if(allDaemons.isEmpty) {
        print(chalk.red('No daemons found. Please create a daemon first (option 11).'));
        break;
      }

      final List<Daemon> daemonsList = allDaemons.toList();
      final String? daemonId = await CliMenuHelper.selectDaemonId(daemonsList);
      if(daemonId == null || daemonId.isEmpty) {
        print(chalk.yellow('Cancelled daemon selection'));
        break;
      }

      final Daemon selectedDaemon = daemonsList.firstWhere((d) => d.id == daemonId);

      stdout.write(chalk.white('\nEnter device name (press Enter to default to "default"): '));
      String? deviceName = stdin.readLineSync();
      if(deviceName == null) {
        print(chalk.red('Invalid device name: $deviceName'));
        break;
      }
      if(deviceName.isEmpty) {
        deviceName = 'default';
      }

      stdout.write(chalk.white('Enter device group name (press Enter to default to "__none__"): '));
      String? deviceGroupName = stdin.readLineSync();
      if(deviceGroupName == null) {
        print(chalk.red('Invalid device group name: $deviceGroupName'));
        break;
      }
      if(deviceGroupName.isEmpty) {
        deviceGroupName = '__none__';
      }

      print(chalk.bold.white('\nConfirm creation of Service:'));
      print('  ${chalk.cyan('daemonId')}: $daemonId (${selectedDaemon.atSign})');
      print('  ${chalk.cyan('deviceName')}: $deviceName');
      print('  ${chalk.cyan('deviceGroupName')}: $deviceGroupName');

      final bool confirmed = CliMenuHelper.confirm('Create this Service?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of Service'));
        break;
      }

      final String serviceId = await policyClient.putService(Service(
        daemonId: daemonId,
        deviceName: deviceName,
        deviceGroupName: deviceGroupName));
      print(chalk.green('✓ Put service with generated id: $serviceId'));
      break;
    }
    case '13': { // putServiceACL
      print(chalk.blue('Fetching available services...'));
      final Set<Service> allServices = await policyClient.getAllServices();
      if(allServices.isEmpty) {
        print(chalk.red('No services found. Please create a service first (option 12).'));
        break;
      }

      final List<Service> servicesList = allServices.toList();
      final String? serviceId = await CliMenuHelper.selectServiceId(servicesList);
      if(serviceId == null || serviceId.isEmpty) {
        print(chalk.yellow('Cancelled service selection'));
        break;
      }

      final Service selectedService = servicesList.firstWhere((s) => s.id == serviceId);

      print(chalk.blue('\nFetching available client groups...'));
      final Set<ClientGroup> allClientGroups = await policyClient.getAllClientGroups();
      if(allClientGroups.isEmpty) {
        print(chalk.red('No client groups found. Please create a client group first (option 9).'));
        break;
      }

      final List<ClientGroup> clientGroupsList = allClientGroups.toList();
      final String? clientGroupId = await CliMenuHelper.selectClientGroupId(clientGroupsList);
      if(clientGroupId == null || clientGroupId.isEmpty) {
        print(chalk.yellow('Cancelled client group selection'));
        break;
      }

      final ClientGroup selectedClientGroup = clientGroupsList.firstWhere((cg) => cg.id == clientGroupId);

      stdout.write(chalk.white('\nEnter permit open (e.g. "localhost:22"): '));
      final String? permitOpen = stdin.readLineSync();
      if(permitOpen == null || permitOpen.isEmpty) {
        print(chalk.red('Invalid permit open: $permitOpen'));
        break;
      }

      print(chalk.bold.white('\nConfirm creation of ServiceACL:'));
      print('  ${chalk.cyan('serviceId')}: $serviceId (${selectedService.deviceName})');
      print('  ${chalk.cyan('clientGroupId')}: $clientGroupId (${selectedClientGroup.name})');
      print('  ${chalk.cyan('permitOpen')}: $permitOpen');

      final bool confirmed = CliMenuHelper.confirm('Grant ${selectedClientGroup.name} access to ${selectedService.deviceName} at $permitOpen?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled creation of ServiceACL'));
        break;
      }

      final String serviceACLId = await policyClient.putServiceACL(ServiceACL(
        serviceId: serviceId,
        clientGroupId: clientGroupId,
        permitOpen: permitOpen));
      print(chalk.green('✓ Put service ACL with generated id: $serviceACLId'));
      break;
    }
    default: {
      print(chalk.red('✗ Invalid option: $option'));
      break;
    }
  }
  print('');
}
}

String showMenuAndGetSelection() {
  print(chalk.bold.blue('\n╔════════════════════════════════════════╗'));
  print(chalk.bold.blue('║          Policy CLI Menu               ║'));
  print(chalk.bold.blue('╚════════════════════════════════════════╝'));

  final List<String> menuItems = [
    chalk.magenta('1. ') + 'ping',
    chalk.cyan('2. ') + 'getAllClients',
    chalk.cyan('3. ') + 'getAllClientGroups',
    chalk.cyan('4. ') + 'getAllClientGroupMembers',
    chalk.cyan('5. ') + 'getAllDaemons',
    chalk.cyan('6. ') + 'getAllServices',
    chalk.cyan('7. ') + 'getAllServiceACLs',
    chalk.green('8. ') + 'putClient',
    chalk.green('9. ') + 'putClientGroup',
    chalk.green('10. ') + 'putClientGroupMember',
    chalk.green('11. ') + 'putDaemon',
    chalk.green('12. ') + 'putService',
    chalk.green('13. ') + 'putServiceACL',
  ];

  print(chalk.white('\nSelect an option (use arrow keys):'));
  final menu = Menu(menuItems);
  final result = menu.choose();
  return (result.index + 1).toString();
}

AtOnboardingPreference generateAtOnboardingPreference(
  NPPCLIParams nppCLIParams
) {
  final AtOnboardingPreference atOnboardingPreference = AtOnboardingPreference()
  ..rootDomain = nppCLIParams.rootServer.split(':')[0]
  ..rootPort = int.parse(nppCLIParams.rootServer.split(':')[1])
  ..atKeysFilePath = nppCLIParams.atKeysFilePath;

  if(nppCLIParams.storagePath != null) {
    atOnboardingPreference.hiveStoragePath = nppCLIParams.storagePath;
  }

  return atOnboardingPreference;
}
