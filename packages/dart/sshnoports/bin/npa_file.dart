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
///     - --> is there a value at permissions[@client][@daemon]
///   - and
///   - 2a. permitted to talk to this daemon's deviceName
///      - --> is there a value at permissions[@client][@daemon]['deviceNames'][$deviceName]
///   - or
///   - 2b. permitted to talk to this daemon's deviceGroupName
///     - --> is there a value at permissions[@client][@daemon]['deviceGroupNames'][$deviceGroupName]
///
/// - The value at 2a or 2b should be a list of permitOpens (hostMask:portMask)
///
/// We'll start with a map exactly as described above. By definition, it will be
/// fully denormalized. We will implement a more normalized structure later.
class FileBasedPolicy implements NPARequestHandler {
  YamlMap yaml;

  final Set<String> _daemonAtsigns = {};

  FileBasedPolicy(this.yaml) {
    // iterate through the map, gather all of the daemon atSigns
    // top level keys are the client atSigns
    for (String clientAtsign in yaml.keys) {
      // Next level is a map of daemonAtsigns
      for (String daemonAtsign in yaml[clientAtsign].keys) {
        _daemonAtsigns.add(daemonAtsign);
      }
    }
  }

  Set<String> get daemonAtsigns => _daemonAtsigns;

  @override
  Future<NPAAuthCheckResponse> doAuthCheck(
      NPAAuthCheckRequest authCheckRequest) async {
    /// - The policy service needs to check if the clientAtsign is
    ///   - 1. permitted to talk to this daemonAtsign
    ///     - --> is there a value at permissions[@client][@daemon]
    final clientEntry = yaml[authCheckRequest.clientAtsign];
    if (clientEntry == null) {
      return NPAAuthCheckResponse(
        authorized: false,
        message: 'No permissions for ${authCheckRequest.clientAtsign}',
        permitOpen: [],
      );
    }
    final daemonEntry = clientEntry[authCheckRequest.daemonAtsign];
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

  // TODO move to unit tests
  // ignore: unused_element
  _randomChecks() {
    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'mbp',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@garycasey',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'gary_windows_box_1',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@garycasey',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'mbp',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@cconstab',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'gary_windows_box_1',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@cconstab',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'mbp',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@colin',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'gary_windows_box_1',
      daemonDeviceGroupName: 'gary_home',
      clientAtsign: '@colin',
    )).then((resp) => print(resp));

    doAuthCheck(NPAAuthCheckRequest(
      daemonAtsign: '@baboonblue18',
      daemonDeviceName: 'gary_lab_device_1',
      daemonDeviceGroupName: 'gary_lab',
      clientAtsign: '@colin',
    )).then((resp) => print(resp));
  }
}
