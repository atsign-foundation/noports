import 'dart:io';

import 'package:admin_api/src/expose_apis.dart' as expose;
import 'package:alfred/alfred.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:noports_core/admin.dart';

void main(List<String> args) async {
  CLIBase cli = await CLIBase.fromCommandLineArgs(args);
  final api = PolicyService.withAtClient(atClient: cli.atClient);
  await api.init();

  // await _createGroups(api); // useful for testing

  final app = Alfred();
  app.all('*', cors(origin: 'http://localhost:5173'));
  if (Platform.executable.contains('admin_api')) {
    // Production usage - we're using the compiled binary
    final executableLocation =
        (Platform.resolvedExecutable.split(Platform.pathSeparator)
              ..removeLast())
            .join(Platform.pathSeparator);
    final dir = Directory(
        [executableLocation, 'web', 'admin'].join(Platform.pathSeparator));
    print ('Will serve webapp from $dir');
    app.get('/*', (req, res) => dir);
  } else {
    // TODO Maybe do something smarter here, but this is for dev purposes only
    final dir = Directory('../../../apps/admin/webapp/dist');
    print ('Will serve webapp from ${dir.absolute}');
    app.get('/*', (req, res) => dir);
  }
  await expose.policy(app, '/api/policy', api);
  await app.listen();
}

// ignore: unused_element
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
      DeviceGroup(
          name: 'atsign_staging_cloud', permitOpens: ['localhost:*', '*:22'])
    ],
  );

  await api.createUserGroup(sysAdmins);

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
  await api.createUserGroup(policyOwners);

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
  await api.createUserGroup(rdpUsers);
}
