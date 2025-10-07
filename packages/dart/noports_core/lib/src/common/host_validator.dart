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

  /// Resolves a host to an InternetAddress with optional address type filtering
  static Future<InternetAddress?> resolveHost(
    String host, {
    InternetAddressType? addressType,
  }) async {
    try {
      // Try to parse as IP address first
      final parsed = InternetAddress.tryParse(host.trim());
      if (parsed != null) {
        // Check if parsed IP matches required address type
        if (addressType != null && parsed.type != addressType) {
          return null;
        }
        return parsed;
      }

      // If not a valid IP, try to resolve as hostname
      final addresses = await InternetAddress.lookup(
        host.trim(),
        type: addressType ?? InternetAddressType.any,
      );
      return addresses.isNotEmpty ? addresses.first : null;
    } catch (e) {
      return null;
    }
  }

  /// Tests if a host:port combination can be bound to
  static Future<bool> canBind(
    String host,
    int port, {
    InternetAddressType? addressType,
  }) async {
    try {
      final address = await resolveHost(host, addressType: addressType);
      if (address == null) return false;

      final serverSocket = await ServerSocket.bind(address, port);
      await serverSocket.close();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Finds the first host from a comma-separated list that can bind to the specified port
  static Future<String?> findBindableHost(
    String hostsString,
    int port, {
    InternetAddressType? addressType,
  }) async {
    final hosts = parseHostsList(hostsString);

    for (String host in hosts) {
      if (await canBind(host, port, addressType: addressType)) {
        return host;
      }
    }

    return null;
  }
}
