class SshnpDeviceList {
  final Map<String, dynamic> info = {};
  final Set<String> activeDevices = {};

  SshnpDeviceList();

  void setActive(String device) {
    if (info.containsKey(device)) {
      activeDevices.add(device);
    }
  }

  Set<String> get inactiveDevices =>
      info.keys.toSet().difference(activeDevices);
}
