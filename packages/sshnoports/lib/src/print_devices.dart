import 'dart:io';

import 'package:noports_core/sshnp_foundation.dart';

void printDevices(SshnpDeviceList deviceList) {
  if (deviceList.activeDevices.isEmpty && deviceList.inactiveDevices.isEmpty) {
    stderr.writeln('[X] No devices found\n');
    stderr.writeln(
        'Note: only devices with sshnpd version 3.4.0 or higher are supported by this command.');
    stderr.writeln(
        'Please update your devices to sshnpd version >= 3.4.0 and try again.');
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
    stderr.writeln('  $device - v${info[device]?['version']}');
  }
}