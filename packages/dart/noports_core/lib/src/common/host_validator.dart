import 'dart:io';

/// Utility class for validating and parsing host addresses
class HostValidator {
  /// Validates a single host (IP address or hostname) by checking if it can be parsed as an IP
  /// or resolved as a hostname
  static Future<bool> isValidHost(String host) async {
    if (host.trim().isEmpty) return false;

    // Try to parse as IP address first
    if (InternetAddress.tryParse(host.trim()) != null) {
      return true;
    }

    // If not a valid IP, try to resolve as hostname
    try {
      await InternetAddress.lookup(host.trim());
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a comma-separated list of hosts and returns the first valid one
  /// Returns null if no valid hosts are found
  static Future<String?> findFirstValidHost(String hostsString) async {
    final hosts = hostsString
        .split(',')
        .map<String>((host) => host.trim())
        .where((String host) => host.isNotEmpty)
        .toList();

    for (String host in hosts) {
      if (await isValidHost(host)) {
        return host;
      }
    }

    return null;
  }

  /// Parses a comma-separated list of hosts and returns all valid ones
  static Future<List<String>> findValidHosts(String hostsString) async {
    final hosts = hostsString
        .split(',')
        .map<String>((host) => host.trim())
        .where((String host) => host.isNotEmpty)
        .toList();

    List<String> validHosts = [];
    for (String host in hosts) {
      if (await isValidHost(host)) {
        validHosts.add(host);
      }
    }

    return validHosts;
  }

  /// Splits a comma-separated string into a list of trimmed, non-empty hosts
  static List<String> parseHostsList(String hostsString) {
    return hostsString
        .split(',')
        .map<String>((host) => host.trim())
        .where((String host) => host.isNotEmpty)
        .toList();
  }
}
