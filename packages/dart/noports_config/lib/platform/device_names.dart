import 'dart:io';

import 'package:noports_core/utils.dart'
    show snakifyDeviceName, sshnpDeviceNameRegex;

/// Device names as sshnpd accepts them: 2 to 36 lowercase letters, digits,
/// "_" or "-", not starting with "-". The rule is noports_core's
/// [sshnpDeviceNameRegex], the same one the daemon and NoPorts Desktop
/// check against.
class DeviceNames {
  DeviceNames._();

  static final RegExp _valid = RegExp('^$sshnpDeviceNameRegex\$');

  static const String rule =
      'Use 2-36 lowercase letters, digits, "_" or "-", not starting with "-".';

  static bool isValid(String? s) => s != null && _valid.hasMatch(s);

  /// What the daemon makes of a typed name before checking it: lower case,
  /// runs of white space as one "_" (noports_core's snakifyDeviceName). So
  /// "My Laptop" is stored and shown as "my_laptop", the name clients use.
  static String snakify(String s) => snakifyDeviceName(s.trim());

  /// A valid device name derived from [hostname] (default: this machine's):
  /// the first label, lowercased, with anything else turned into "_",
  /// trimmed to 36 characters. Falls back to "default" when nothing usable
  /// is left.
  static String fromHostname([String? hostname]) {
    final host = (hostname ?? Platform.localHostname).split('.').first;
    var name = host
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]'), '_')
        .replaceAll(RegExp(r'^-+'), '');
    if (name.length > 36) name = name.substring(0, 36);
    return isValid(name) ? name : 'default';
  }
}
