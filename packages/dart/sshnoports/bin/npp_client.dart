import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/npp.dart';
import 'package:noports_core/utils.dart';
import 'package:chalkdart/chalk.dart';
import 'package:cli_menu/cli_menu.dart';
import 'package:sshnoports/src/print_version.dart';
import 'package:sshnoports/src/cli_menu_helper.dart';
import 'package:noports_core/npa.dart';


late AtSignLogger logger;

const String _description =
    'NoPorts policy CLI: manage the policy data used by NoPorts'
    ' policy services.';

Future<void> main(List<String> args) async {
  logger = AtSignLogger('  policy_cli  ');

  // Handle --help and --version flags before parsing
  try {
    final argResults = NPPCLIParams.argParser.parse(args);
    if (argResults['help']) {
      stdout.write(formatCliHelp(
          description: _description,
          optionsUsage: NPPCLIParams.argParser.usage));
      exit(0);
    }
    if (argResults['version']) {
      printVersion();
      exit(0);
    }
  } on FormatException catch (e) {
    stderr.writeln('Error: ${e.message}');
    stderr.write(formatCliHelp(
        description: _description,
        optionsUsage: NPPCLIParams.argParser.usage));
    exit(1);
  } catch (e) {
    // Continue to fromArgs which will handle other errors
  }

  final NPPCLIParams nppCLIParams;
  try {
    nppCLIParams = NPPCLIParams.fromArgs(args);
  } catch (e) {
    stderr.writeln('Error: $e');
    stderr.write(formatCliHelp(
        description: _description,
        optionsUsage: NPPCLIParams.argParser.usage));
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

  final NppClient nppClient = NppClient(
    atClient: atClient,
    serverAtSign: nppCLIParams.policyAtSign,
    baseNameSpace: nppCLIParams.baseNamespace,
    domainNameSpace: nppCLIParams.domainNamespace!,
  );


  while(true) {
  final String option = showMenuAndGetSelection();
  switch(option) {
    case '1': { // ping
      print(chalk.blue('\nSending ping request...'));
      try {
        final Map<String, dynamic> pingResponse = await nppClient.ping();
        print(chalk.green('\n✓ Ping successful!'));
        print('  ${chalk.cyan('status')}: ${pingResponse['status']}');
        print('  ${chalk.cyan('binariesVersion')}: ${pingResponse['binariesVersion']}');
        print('  ${chalk.cyan('coreVersion')}: ${pingResponse['coreVersion']}');
        print('  ${chalk.cyan('timestamp')}: ${pingResponse['timestamp']}');
      } catch (e) {
        print(chalk.red('\n✗ Ping failed: $e'));
      }
      break;
    }
    case '2': { // simulate
      try {
        print(chalk.blue('\nSending simulate request...'));
        stdout.write(chalk.white('\nEnter daemon atSign: '));
        final String daemonAtsign =
            AtUtils.fixAtSign(stdin.readLineSync()!);

        stdout.write(chalk.white(
            'Enter device name (press Enter to default to "default"): '));
        String? deviceName = stdin.readLineSync();
        if (deviceName == null || deviceName.isEmpty) {
          deviceName = 'default';
        }
        stdout.write(chalk.white(
            'Enter device group name (press Enter to default to "__none__"): '));
        String? deviceGroupName = stdin.readLineSync();
        if (deviceGroupName == null || deviceGroupName.isEmpty) {
          deviceGroupName = '__none__';
        }

        stdout.write(chalk.white('Enter client atSign: '));
        final String clientAtsign =
            AtUtils.fixAtSign(stdin.readLineSync()!);

        try {
          final NPAAuthCheckResponse authCheckResponse =
            await nppClient.simulate(
              daemonAtsign: daemonAtsign,
              deviceName: deviceName,
              deviceGroupName: deviceGroupName,
              clientAtsign: clientAtsign,
            );
          print(chalk.green('\n✓ Simulate successful!'));
          print('  ${chalk.cyan('status')}: ${authCheckResponse.authorized}');
          print('  ${chalk.cyan('message')}: ${authCheckResponse.message}');
          if (authCheckResponse.authorized) {
            print('  ${chalk.cyan('permitOpen')}: ${authCheckResponse.permitOpen}');
          }
        } catch (e) {
          print(chalk.red('\n✗ Simulate failed: $e'));
        }
      } catch (e) {
        print(chalk.red('\n✗ Invalid daemon atSign: $e'));
      }
      break;
    }
    case '3': { // getAllClients
      final Set<Client> allClients = await nppClient.getAllClients();
      print(chalk.green('\n✓ Obtained ${allClients.length} clients:'));
      for(int i = 0; i < allClients.length; i++) {
        final Client client = allClients.elementAt(i);
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(client.id ?? 'N/A')} | atSign: ${client.atSign} | name: ${client.name}');
      }
      break;
    }
    case '4': { // getAllClientGroups
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      print(chalk.green('\n✓ Obtained ${allClientGroups.length} client groups:'));
      for(int i = 0; i < allClientGroups.length; i++) {
        final ClientGroup clientGroup = allClientGroups.elementAt(i);
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(clientGroup.id ?? 'N/A')} | name: ${clientGroup.name}');
      }
      break;
    }
    case '5': { // getAllClientGroupMembers
      // Fetch all data for lookups
      final Set<Client> allClients = await nppClient.getAllClients();
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      final Set<ClientGroupMember> allClientGroupMembers = await nppClient.getAllClientGroupMembers();

      // Build lookup maps
      final Map<String, Client> clientsById = {for (var c in allClients) if (c.id != null) c.id!: c};
      final Map<String, ClientGroup> groupsById = {for (var g in allClientGroups) if (g.id != null) g.id!: g};

      print(chalk.green('\n✓ Obtained ${allClientGroupMembers.length} client group members:'));
      for(int i = 0; i < allClientGroupMembers.length; i++) {
        final ClientGroupMember cgm = allClientGroupMembers.elementAt(i);
        final Client? client = clientsById[cgm.clientId];
        final ClientGroup? group = groupsById[cgm.clientGroupId];
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(cgm.id ?? 'N/A')} | '
          'clientId: ${cgm.clientId} (${client?.atSign ?? '?'}) | '
          'clientGroupId: ${cgm.clientGroupId} (${group?.name ?? '?'})');
      }
      break;
    }
    case '6': { // getAllDaemons
      final Set<Daemon> allDaemons = await nppClient.getAllDaemons();
      print(chalk.green('\n✓ Obtained ${allDaemons.length} daemons:'));
      for(int i = 0; i < allDaemons.length; i++) {
        final Daemon daemon = allDaemons.elementAt(i);
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(daemon.id ?? 'N/A')} | atSign: ${daemon.atSign}');
      }
      break;
    }
    case '7': { // getAllServices
      // Fetch all data for lookups
      final Set<Daemon> allDaemons = await nppClient.getAllDaemons();
      final Set<Service> allServices = await nppClient.getAllServices();

      // Build lookup map
      final Map<String, Daemon> daemonsById = {for (var d in allDaemons) if (d.id != null) d.id!: d};

      print(chalk.green('\n✓ Obtained ${allServices.length} services:'));
      for(int i = 0; i < allServices.length; i++) {
        final Service service = allServices.elementAt(i);
        final Daemon? daemon = daemonsById[service.daemonId];
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(service.id ?? 'N/A')} | '
          'deviceName: ${service.deviceName} | '
          'deviceGroupName: ${service.deviceGroupName} | '
          'daemonId: ${service.daemonId} (${daemon?.atSign ?? '?'})');
      }
      break;
    }
    case '8': { // getAllServiceACLs
      // Fetch all data for lookups
      final Set<Service> allServices = await nppClient.getAllServices();
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      final Set<ServiceACL> allServiceACLs = await nppClient.getAllServiceACLs();

      // Build lookup maps
      final Map<String, Service> servicesById = {for (var s in allServices) if (s.id != null) s.id!: s};
      final Map<String, ClientGroup> groupsById = {for (var g in allClientGroups) if (g.id != null) g.id!: g};

      print(chalk.green('\n✓ Obtained ${allServiceACLs.length} service ACLs:'));
      for(int i = 0; i < allServiceACLs.length; i++) {
        final ServiceACL acl = allServiceACLs.elementAt(i);
        final Service? service = servicesById[acl.serviceId];
        final ClientGroup? group = groupsById[acl.clientGroupId];
        print('  ${chalk.cyan('[$i]')}: id: ${chalk.yellow(acl.id ?? 'N/A')} | '
          'serviceId: ${acl.serviceId} (${service?.deviceName ?? '?'}) | '
          'clientGroupId: ${acl.clientGroupId} (${group?.name ?? '?'}) | '
          'permitOpen: ${acl.permitOpen}');
      }
      break;
    }
    case '9': { // putClient
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

      final String clientId = await nppClient.putClient(Client(
          name: clientName,
          atSign: clientAtSign));
      print(chalk.green('✓ Put client with generated id: $clientId'));
      break;
    }
    case '10': { // putClientGroup
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

      final String clientGroupId = await nppClient.putClientGroup(ClientGroup(
        name: clientGroupName));
      print(chalk.green('✓ Put client group with generated id: $clientGroupId'));
      break;
    }
    case '11': { // putClientGroupMember
      print(chalk.blue('Fetching available clients...'));
      final Set<Client> allClients = await nppClient.getAllClients();
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
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
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

      final String clientGroupMemberId = await nppClient.putClientGroupMember(ClientGroupMember(
        clientGroupId: clientGroupId,
        clientId: clientId));
      print(chalk.green('✓ Put client group member with generated id: $clientGroupMemberId'));
      break;
    }
    case '12': { // putDaemon
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

      final String daemonId = await nppClient.putDaemon(Daemon(
        atSign: daemonAtSign));
      print(chalk.green('✓ Put daemon with generated id: $daemonId'));
      break;
    }
    case '13': { // putService
      print(chalk.blue('Fetching available daemons...'));
      final Set<Daemon> allDaemons = await nppClient.getAllDaemons();
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

      final String serviceId = await nppClient.putService(Service(
        daemonId: daemonId,
        deviceName: deviceName,
        deviceGroupName: deviceGroupName));
      print(chalk.green('✓ Put service with generated id: $serviceId'));
      break;
    }
    case '14': { // putServiceACL
      print(chalk.blue('Fetching available services...'));
      final Set<Service> allServices = await nppClient.getAllServices();
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
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
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

      final String serviceACLId = await nppClient.putServiceACL(ServiceACL(
        serviceId: serviceId,
        clientGroupId: clientGroupId,
        permitOpen: permitOpen));
      print(chalk.green('✓ Put service ACL with generated id: $serviceACLId'));
      break;
    }
    case '15': { // deleteClient
      print(chalk.blue('Fetching available clients...'));
      final Set<Client> allClients = await nppClient.getAllClients();
      if(allClients.isEmpty) {
        print(chalk.red('No clients found.'));
        break;
      }

      final List<Client> clientsList = allClients.toList();
      final String? clientId = await CliMenuHelper.selectClientId(clientsList);
      if(clientId == null || clientId.isEmpty) {
        print(chalk.yellow('Cancelled client selection'));
        break;
      }

      final Client selectedClient = clientsList.firstWhere((c) => c.id == clientId);

      print(chalk.bold.red('\nConfirm deletion of Client:'));
      print('  ${chalk.cyan('id')}: $clientId');
      print('  ${chalk.cyan('atSign')}: ${selectedClient.atSign}');
      print('  ${chalk.cyan('name')}: ${selectedClient.name}');

      final bool confirmed = CliMenuHelper.confirm('Delete this Client?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of Client'));
        break;
      }

      final bool success = await nppClient.deleteClient(clientId);
      if(success) {
        print(chalk.green('✓ Deleted client with id: $clientId'));
      } else {
        print(chalk.red('✗ Failed to delete client with id: $clientId'));
      }
      break;
    }
    case '16': { // deleteClientGroup
      print(chalk.blue('Fetching available client groups...'));
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      if(allClientGroups.isEmpty) {
        print(chalk.red('No client groups found.'));
        break;
      }

      final List<ClientGroup> clientGroupsList = allClientGroups.toList();
      final String? clientGroupId = await CliMenuHelper.selectClientGroupId(clientGroupsList);
      if(clientGroupId == null || clientGroupId.isEmpty) {
        print(chalk.yellow('Cancelled client group selection'));
        break;
      }

      final ClientGroup selectedClientGroup = clientGroupsList.firstWhere((cg) => cg.id == clientGroupId);

      print(chalk.bold.red('\nConfirm deletion of ClientGroup:'));
      print('  ${chalk.cyan('id')}: $clientGroupId');
      print('  ${chalk.cyan('name')}: ${selectedClientGroup.name}');

      final bool confirmed = CliMenuHelper.confirm('Delete this ClientGroup?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of ClientGroup'));
        break;
      }

      final bool success = await nppClient.deleteClientGroup(clientGroupId);
      if(success) {
        print(chalk.green('✓ Deleted client group with id: $clientGroupId'));
      } else {
        print(chalk.red('✗ Failed to delete client group with id: $clientGroupId'));
      }
      break;
    }
    case '17': { // deleteClientGroupMember
      print(chalk.blue('Fetching available client group members...'));
      final Set<Client> allClients = await nppClient.getAllClients();
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      final Set<ClientGroupMember> allClientGroupMembers = await nppClient.getAllClientGroupMembers();

      if(allClientGroupMembers.isEmpty) {
        print(chalk.red('No client group members found.'));
        break;
      }

      // Build lookup maps
      final Map<String, Client> clientsById = {for (var c in allClients) if (c.id != null) c.id!: c};
      final Map<String, ClientGroup> groupsById = {for (var g in allClientGroups) if (g.id != null) g.id!: g};

      // Let user select from list
      final List<ClientGroupMember> cgmList = allClientGroupMembers.toList();
      print(chalk.white('\nSelect a client group member to delete:'));
      final List<String> menuItems = [];
      for(int i = 0; i < cgmList.length; i++) {
        final ClientGroupMember cgm = cgmList[i];
        final Client? client = clientsById[cgm.clientId];
        final ClientGroup? group = groupsById[cgm.clientGroupId];
        menuItems.add('${i + 1}. id: ${cgm.id} | client: ${client?.atSign ?? '?'} | group: ${group?.name ?? '?'}');
      }
      final menu = Menu(menuItems);
      final result = menu.choose();
      final ClientGroupMember selectedCgm = cgmList[result.index];

      final Client? client = clientsById[selectedCgm.clientId];
      final ClientGroup? group = groupsById[selectedCgm.clientGroupId];

      print(chalk.bold.red('\nConfirm deletion of ClientGroupMember:'));
      print('  ${chalk.cyan('id')}: ${selectedCgm.id}');
      print('  ${chalk.cyan('client')}: ${client?.atSign ?? '?'}');
      print('  ${chalk.cyan('group')}: ${group?.name ?? '?'}');

      final bool confirmed = CliMenuHelper.confirm('Delete this ClientGroupMember?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of ClientGroupMember'));
        break;
      }

      final bool success = await nppClient.deleteClientGroupMember(selectedCgm.id!);
      if(success) {
        print(chalk.green('✓ Deleted client group member with id: ${selectedCgm.id}'));
      } else {
        print(chalk.red('✗ Failed to delete client group member with id: ${selectedCgm.id}'));
      }
      break;
    }
    case '18': { // deleteDaemon
      print(chalk.blue('Fetching available daemons...'));
      final Set<Daemon> allDaemons = await nppClient.getAllDaemons();
      if(allDaemons.isEmpty) {
        print(chalk.red('No daemons found.'));
        break;
      }

      final List<Daemon> daemonsList = allDaemons.toList();
      final String? daemonId = await CliMenuHelper.selectDaemonId(daemonsList);
      if(daemonId == null || daemonId.isEmpty) {
        print(chalk.yellow('Cancelled daemon selection'));
        break;
      }

      final Daemon selectedDaemon = daemonsList.firstWhere((d) => d.id == daemonId);

      print(chalk.bold.red('\nConfirm deletion of Daemon:'));
      print('  ${chalk.cyan('id')}: $daemonId');
      print('  ${chalk.cyan('atSign')}: ${selectedDaemon.atSign}');

      final bool confirmed = CliMenuHelper.confirm('Delete this Daemon?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of Daemon'));
        break;
      }

      final bool success = await nppClient.deleteDaemon(daemonId);
      if(success) {
        print(chalk.green('✓ Deleted daemon with id: $daemonId'));
      } else {
        print(chalk.red('✗ Failed to delete daemon with id: $daemonId'));
      }
      break;
    }
    case '19': { // deleteService
      print(chalk.blue('Fetching available services...'));
      final Set<Daemon> allDaemons = await nppClient.getAllDaemons();
      final Set<Service> allServices = await nppClient.getAllServices();
      if(allServices.isEmpty) {
        print(chalk.red('No services found.'));
        break;
      }

      // Build lookup map
      final Map<String, Daemon> daemonsById = {for (var d in allDaemons) if (d.id != null) d.id!: d};

      final List<Service> servicesList = allServices.toList();
      final String? serviceId = await CliMenuHelper.selectServiceId(servicesList);
      if(serviceId == null || serviceId.isEmpty) {
        print(chalk.yellow('Cancelled service selection'));
        break;
      }

      final Service selectedService = servicesList.firstWhere((s) => s.id == serviceId);
      final Daemon? daemon = daemonsById[selectedService.daemonId];

      print(chalk.bold.red('\nConfirm deletion of Service:'));
      print('  ${chalk.cyan('id')}: $serviceId');
      print('  ${chalk.cyan('daemon')}: ${daemon?.atSign ?? '?'}');
      print('  ${chalk.cyan('deviceName')}: ${selectedService.deviceName}');
      print('  ${chalk.cyan('deviceGroupName')}: ${selectedService.deviceGroupName}');

      final bool confirmed = CliMenuHelper.confirm('Delete this Service?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of Service'));
        break;
      }

      final bool success = await nppClient.deleteService(serviceId);
      if(success) {
        print(chalk.green('✓ Deleted service with id: $serviceId'));
      } else {
        print(chalk.red('✗ Failed to delete service with id: $serviceId'));
      }
      break;
    }
    case '20': { // deleteServiceACL
      print(chalk.blue('Fetching available service ACLs...'));
      final Set<Service> allServices = await nppClient.getAllServices();
      final Set<ClientGroup> allClientGroups = await nppClient.getAllClientGroups();
      final Set<ServiceACL> allServiceACLs = await nppClient.getAllServiceACLs();

      if(allServiceACLs.isEmpty) {
        print(chalk.red('No service ACLs found.'));
        break;
      }

      // Build lookup maps
      final Map<String, Service> servicesById = {for (var s in allServices) if (s.id != null) s.id!: s};
      final Map<String, ClientGroup> groupsById = {for (var g in allClientGroups) if (g.id != null) g.id!: g};

      // Let user select from list
      final List<ServiceACL> aclList = allServiceACLs.toList();
      print(chalk.white('\nSelect a service ACL to delete:'));
      final List<String> menuItems = [];
      for(int i = 0; i < aclList.length; i++) {
        final ServiceACL acl = aclList[i];
        final Service? service = servicesById[acl.serviceId];
        final ClientGroup? group = groupsById[acl.clientGroupId];
        menuItems.add('${i + 1}. id: ${acl.id} | service: ${service?.deviceName ?? '?'} | group: ${group?.name ?? '?'} | permitOpen: ${acl.permitOpen}');
      }
      final menu = Menu(menuItems);
      final result = menu.choose();
      final ServiceACL selectedAcl = aclList[result.index];

      final Service? service = servicesById[selectedAcl.serviceId];
      final ClientGroup? group = groupsById[selectedAcl.clientGroupId];

      print(chalk.bold.red('\nConfirm deletion of ServiceACL:'));
      print('  ${chalk.cyan('id')}: ${selectedAcl.id}');
      print('  ${chalk.cyan('service')}: ${service?.deviceName ?? '?'}');
      print('  ${chalk.cyan('group')}: ${group?.name ?? '?'}');
      print('  ${chalk.cyan('permitOpen')}: ${selectedAcl.permitOpen}');

      final bool confirmed = CliMenuHelper.confirm('Delete this ServiceACL?');
      if(!confirmed) {
        print(chalk.yellow('Cancelled deletion of ServiceACL'));
        break;
      }

      final bool success = await nppClient.deleteServiceACL(selectedAcl.id!);
      if(success) {
        print(chalk.green('✓ Deleted service ACL with id: ${selectedAcl.id}'));
      } else {
        print(chalk.red('✗ Failed to delete service ACL with id: ${selectedAcl.id}'));
      }
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
    '${chalk.magenta('1. ')}ping',
    '${chalk.magenta('2. ')}simulate',
    '${chalk.cyan('3. ')}getAllClients',
    '${chalk.cyan('4. ')}getAllClientGroups',
    '${chalk.cyan('5. ')}getAllClientGroupMembers',
    '${chalk.cyan('6. ')}getAllDaemons',
    '${chalk.cyan('7. ')}getAllServices',
    '${chalk.cyan('8. ')}getAllServiceACLs',
    '${chalk.green('9. ')}putClient',
    '${chalk.green('10. ')}putClientGroup',
    '${chalk.green('11. ')}putClientGroupMember',
    '${chalk.green('12. ')}putDaemon',
    '${chalk.green('13. ')}putService',
    '${chalk.green('14. ')}putServiceACL',
    '${chalk.red('15. ')}deleteClient',
    '${chalk.red('16. ')}deleteClientGroup',
    '${chalk.red('17. ')}deleteClientGroupMember',
    '${chalk.red('18. ')}deleteDaemon',
    '${chalk.red('19. ')}deleteService',
    '${chalk.red('20. ')}deleteServiceACL',
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
