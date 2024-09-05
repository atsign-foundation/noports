import 'dart:async';
import 'dart:io';
import 'package:args/args.dart';
import 'package:noports_core/npa.dart';
import 'package:sshnoports/npa_bootstrapper.dart' as bootstrapper;
import 'package:yaml/yaml.dart';

void main(List<String> args) async {
  ArgParser parser = NPAParams.parser;
  parser.addOption(
    'yaml',
    mandatory: true,
    help: 'Path to policy yaml',
  );
  ArgResults r = parser.parse(args);

  YamlMap? yaml = loadYaml(File(r['yaml']).readAsStringSync());

  FileBasedPolicy policy = FileBasedPolicy(yaml!);
  await bootstrapper.run(
    policy,
    args,
    daemonAtsigns: policy.daemonAtsigns,
  );
}

/// - Client atSigns request access to a $deviceName at some $daemonAtSign for $someReason
/// - Daemons run with a deviceName and a deviceGroup
/// - Daemons send the daemonAtsign, clientAtSign, deviceName and deviceGroup to policy service
/// - The policy service needs to check if the clientAtsign is
///   - 1. permitted to talk to this daemonAtsign
///     - --> is there a value at permissions[@client]['daemons'][@daemon]
///   - and
///   - 2a. permitted to talk to this daemon's deviceName
///      - --> is there a value at permissions[@client]['daemons'][@daemon]['deviceNames'][$deviceName]
///   - or
///   - 2b. permitted to talk to this daemon's deviceGroupName
///     - --> is there a value at permissions[@client]['daemons'][@daemon]['deviceGroupNames'][$deviceGroupName]
///
/// - The value at 2a or 2b will be a list of permitOpens (hostMask:portMask)
///
/// Uses a policy.yaml file like the following:
/// userGroups:
///   "api_users":
///     userAtSigns:
///       - "@alice"
///       - "@bob"
///       - "@chuck"
///       - "@derek"
///     permissions:
///       daemonAtSigns:
///         - "@zaphod"
///         - "@dentarthurdent"
///       deviceNames:
///         "h2g2":
///           - "localhost:3000"
///   "rdp_users":
///     userAtSigns:
///       - "@charlie"
///       - "@filip"
///       - "@dipak"
///     permissions:
///       daemonAtSigns:
///         - "@zaphod"
///         - "@dentarthurdent"
///       deviceNames:
///       deviceGroupNames:
///         "network_name_123":
///           - "*:3389"
///   "ssh_users":
///     userAtSigns:
///       - "@bob"
///     permissions:
///       daemonAtSigns:
///         - "@zaphod"
///         - "@dentarthurdent"
///       deviceGroupNames:
///       deviceNames:
///         "h2g2":
///           - "*:22"
class FileBasedPolicy implements NPARequestHandler {
  YamlMap yaml;

  final Set<String> _daemonAtSigns = {};
  final Map<String, Map> _userAtSigns = {};

  FileBasedPolicy(this.yaml) {
    // Get the full list of daemonAtSigns which this policy service will listen to
    for (String userGroupName in yaml['userGroups'].keys ?? []) {
      for (String daemonAtSign in yaml['userGroups'][userGroupName]
              ['permissions']['daemonAtSigns'] ??
          []) {
        _daemonAtSigns.add(daemonAtSign);
      }
    }
    print(_daemonAtSigns);

    // Create a map of userAtSign->daemonAtSign->deviceNames/deviceGroupNames->[PermitOpens]
    for (String userGroupName in yaml['userGroups'].keys ?? []) {
      final group = yaml['userGroups'][userGroupName];
      for (String userAtSign in group['userAtSigns']) {
        _userAtSigns.putIfAbsent(
            userAtSign, () => {'userGroups': [], 'daemons': {}});
        ((_userAtSigns[userAtSign] as Map)['userGroups'] as List)
            .add(userGroupName);
        Map userDaemonPermissions =
            (_userAtSigns[userAtSign] as Map)['daemons'] as Map;
        for (String daemonAtSign
            in group['permissions']['daemonAtSigns'] ?? []) {
          userDaemonPermissions.putIfAbsent(
              daemonAtSign, () => {'deviceNames': {}, 'deviceGroupNames': {}});

          for (String deviceName
              in (group['permissions']['deviceNames'] ?? {}).keys) {
            Map devicesMap =
                userDaemonPermissions[daemonAtSign]['deviceNames'] as Map;
            devicesMap.putIfAbsent(deviceName, () => []);
            final devicePermissions = devicesMap[deviceName] as List;
            for (String permitOpen in List<String>.from(
                group['permissions']['deviceNames'][deviceName] ?? [])) {
              if (!devicePermissions.contains(permitOpen)) {
                devicePermissions.add(permitOpen);
              }
            }
          }

          for (String deviceGroupName
              in (group['permissions']['deviceGroupNames'] ?? {}).keys) {
            Map deviceGroupsMap =
                userDaemonPermissions[daemonAtSign]['deviceGroupNames'] as Map;
            deviceGroupsMap.putIfAbsent(deviceGroupName, () => []);
            final deviceGroupPermissions =
                deviceGroupsMap[deviceGroupName] as List;
            for (String permitOpen in List<String>.from(group['permissions']
                    ['deviceGroupNames'][deviceGroupName] ??
                [])) {
              if (!deviceGroupPermissions.contains(permitOpen)) {
                deviceGroupPermissions.add(permitOpen);
              }
            }
          }
        }
      }
    }
    for (final u in _userAtSigns.keys) {
      final user = _userAtSigns[u] as Map;
      print('$u is member of groups ${user['userGroups']}');
      for (final d in user['daemons'].keys) {
        print('  daemon: $d');
        var daemon = user['daemons'][d];
        for (final dn in (daemon['deviceNames']).keys) {
          print('    device $dn: ${daemon['deviceNames'][dn]}');
        }
        for (final dgn in (daemon['deviceGroupNames']).keys) {
          print('    deviceGroup $dgn: ${daemon['deviceGroupNames'][dgn]}');
        }
      }
    }
  }

  Set<String> get daemonAtsigns => _daemonAtSigns;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(
      NPAAuthCheckRequest authCheckRequest) async {
    /// - The policy service needs to check if the clientAtsign is
    ///   - 1. permitted to talk to this daemonAtsign
    ///     - --> is there a value at _userAtSigns[@client][@daemon]
    final clientEntry = _userAtSigns[authCheckRequest.clientAtsign];
    if (clientEntry == null) {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}',
        permitOpen: [],
      );
    }
    final daemonEntry = clientEntry['daemons'][authCheckRequest.daemonAtsign];
    if (daemonEntry == null) {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}'
            ' at ${authCheckRequest.daemonAtsign}',
        permitOpen: [],
      );
    }

    ///   - and
    ///   - 2a. permitted to talk to this daemon's deviceName
    ///      - --> is there a value at permissions[@client][@daemon]['deviceNames'][$deviceName]
    final deviceNames = daemonEntry['deviceNames'];
    if (deviceNames != null) {
      final deviceNameEntry = deviceNames[authCheckRequest.daemonDeviceName];
      if (deviceNameEntry != null) {
        return NPAAuthCheckResponse(
          authorized: true,
          message: '${authCheckRequest.clientAtsign} has permission'
              ' for device ${authCheckRequest.daemonDeviceName}'
              ' at daemon ${authCheckRequest.daemonAtsign}',
          permitOpen: List<String>.from(deviceNameEntry),
        );
      }
    }

    ///   - or
    ///   - 2b. permitted to talk to this daemon's deviceGroupName
    ///     - --> is there a value at permissions[@client][@daemon]['deviceGroupNames'][$deviceGroupName]
    final deviceGroupNames = daemonEntry['deviceGroupNames'];
    if (deviceGroupNames != null) {
      final deviceGroupNameEntry =
          deviceGroupNames[authCheckRequest.daemonDeviceGroupName];
      if (deviceGroupNameEntry != null) {
        return NPAAuthCheckResponse(
          authorized: true,
          message: '${authCheckRequest.clientAtsign} has permission'
              ' for device group ${authCheckRequest.daemonDeviceGroupName}'
              ' at daemon ${authCheckRequest.daemonAtsign}',
          permitOpen: List<String>.from(deviceGroupNameEntry),
        );
      }
    }

    return NPAAuthCheckResponse(
      authorized: false,
      message: 'No permissions for ${authCheckRequest.clientAtsign}'
          ' at ${authCheckRequest.daemonAtsign}'
          ' for either the device ${authCheckRequest.daemonDeviceName}'
          ' or the deviceGroup ${authCheckRequest.daemonDeviceGroupName}',
      permitOpen: [],
    );
  }
}
