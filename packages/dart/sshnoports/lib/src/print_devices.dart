import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';

void printDevices(SshnpDeviceList deviceList) {
  if (deviceList.activeDevices.isEmpty && deviceList.inactiveDevices.isEmpty) {
    stderr.writeln('[X] No devices found\n');
    exit(0);
  }

  stderr.writeln('Active Devices:');
  printDeviceList(deviceList.activeDevices, deviceList.info);
  stderr.writeln('Inactive Devices:');
  printDeviceList(deviceList.inactiveDevices, deviceList.info);
}

void printDeviceList(Iterable<String> devices, Map<String, dynamic> info) {
  if (devices.isEmpty) {
    stderr.writeln('  No devices found');
    return;
  }
  for (var device in devices) {
    stderr.writeln('  $device - v${info[device]?['version']}'
        ' (core v${info[device]?['corePackageVersion']})');
    if (info[device]['allowedServices'] != null &&
        (info[device]['allowedServices'] is List<String>) &&
        (info[device]['allowedServices'] as List<String>).isNotEmpty) {
      stderr.write("  - allowedServices:");
      for (String service in info[device]['allowedServices']) {
        stderr.write(' $service');
      }
      stderr.writeln();
    }
  }
}
