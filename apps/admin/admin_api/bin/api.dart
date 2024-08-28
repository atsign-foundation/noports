import 'dart:io';

import 'package:admin_api/src/expose_apis.dart' as expose;
import 'package:alfred/alfred.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:noports_core/admin.dart';

void main(List<String> args) async {
  CLIBase cli = await CLIBase.fromCommandLineArgs(args);
  final api = PolicyService.withAtClient(atClient: cli.atClient);

  await _createUsers(api);
  await _createGroups(api);

  final app = Alfred();
  app.all('*', cors(origin: 'http://localhost:5173'));
  app.get('/static/*', (req, res) => Directory('static'));
  await expose.policy(app, '/api/policy', api);
  await app.listen();
}

Future<void> _createUsers(PolicyService api) async {
  await api.updateUser(User(atSign: '@alice', name: 'Alice'));
  await api.updateUser(User(atSign: '@bob', name: 'Bob'));
  await api.updateUser(User(atSign: '@chuck', name: 'chuck'));
}

Future<void> _createGroups(PolicyService api) async {
  UserGroup sysAdmins = UserGroup(
    name: 'SysAdmins',
    description: 'System Administrators - full access',
    userAtSigns: ['@alice'],
    daemonAtSigns: ['@delta'],
    devices: [
      Device(name: 'bastion1', permitOpens: ['*:*'])
    ],
    deviceGroups: [
      DeviceGroup(name: 'atsign_staging_cloud', permitOpens: ['localhost:*','*:22'])
    ],
  );

  await api.updateUserGroup(sysAdmins);

  UserGroup policyOwners = UserGroup(
    name: 'PolicyOwners',
    description: 'Policy Owners - can connect to policy API',
    userAtSigns: ['@bob'],
    daemonAtSigns: ['@delta'],
    devices: [
      Device(name: 'bastion1', permitOpens: ['localhost:15001'])
    ],
    deviceGroups: [],
  );
  await api.updateUserGroup(policyOwners);

  UserGroup rdpUsers = UserGroup(
    name: 'RdpUsers',
    description: 'RDP Users - can connect to RDP ports on this network',
    userAtSigns: ['@alice', '@bob', '@chuck'],
    daemonAtSigns: ['@delta'],
    devices: [
      Device(name: 'bastion1', permitOpens: ['*:3389'])
    ],
    deviceGroups: [],
  );
  await api.updateUserGroup(rdpUsers);
}
