import 'dart:io';

import 'package:at_utils/at_logger.dart';

class AtLatencyChecker {
  final AtSignLogger logger = AtSignLogger('AtLatencyChecker');

  Future<int> _getLatency(
    String host, {
    int port = 443,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      final latency = stopwatch.elapsedMilliseconds;
      socket.destroy();
      return latency;
    } on SocketException catch (e) {
      logger.warning('Failed to connect to $host:$port | $e');
      return -1;
    } catch (e) {
      logger.severe('getLatency failed for $host:$port | $e');
      return -1;
    } finally {
      stopwatch.stop();
    }
  }

  /// Measures TCP latency from this machine to each RV in [rvServers].
  ///
  /// [rvServers] format:
  /// ```json
  /// {
  ///   "@rv_am": { "ip": "192.0.2.1", "port": 443 },
  ///   "@rv_eu": { "ip": "192.0.2.2", "port": 443 }
  /// }
  /// ```
  ///
  /// Returns a map of RV atSign → latency in milliseconds, or -1 if unreachable.
  Future<Map<String, int>> getRvLatencyMap(
    Map<String, dynamic> rvServers,
  ) async {
    final latencyMap = <String, int>{};

    for (final rv in rvServers.keys) {
      final addr = rvServers[rv] as Map<String, dynamic>;
      final ip = addr['ip'] as String?;
      final port = addr['port'] as int?;

      if (ip == null || port == null) {
        logger.warning('Missing ip or port for $rv, skipping');
        latencyMap[rv] = -1;
        continue;
      }
      latencyMap[rv] = await _getLatency(ip, port: port);
    }

    return latencyMap;
  }

  String getBestRv(
    Map<String, int> daemonLatencies,
    Map<String, int> clientLatencies,
  ) {
    String? bestRv;
    double bestAverage = -1;

    for (final rv in daemonLatencies.keys) {
      final d = daemonLatencies[rv] ?? -1;
      final c = clientLatencies[rv] ?? -1;
      if (d == -1 || c == -1) continue; // skip unreachable RVs

      final average = (d + c) / 2;
      if (bestAverage == -1 || average < bestAverage) {
        bestAverage = average;
        bestRv = rv;
      }
    }

    if (bestRv == null) {
      throw StateError('No reachable RV found');
    }

    return bestRv;
  }
}
