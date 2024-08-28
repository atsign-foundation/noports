class Port {
  // parses a port from string, returns 0 if the parse fails
  static int fromString(String value) {
    int port = int.tryParse(value) ?? 0;
    if (port < 0) port == 0;
    if (port > 65535) port = 65535;
    return port;
  }
}
