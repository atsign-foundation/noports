import 'dart:io';

import 'package:at_utils/at_logger.dart';

const Map<String, List<String>> rvServers = {
  '@rv_ap': ['91.242.241.90', '38.180.106.94'],
  '@rv_eu': ['195.54.161.125', '38.180.8.69'],
  '@rv_am': ['185.28.119.179', '38.180.89.181'],
  '@rv_oc': ['139.99.184.231', '38.180.128.36'],
};

class AtLatencyChecker {
  static AtSignLogger logger = AtSignLogger('AtLatencyChecker');

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

  Future<Map<String, int>> getRvLatencyMap() async {
    final latencyMap = <String, int>{};
    for (final rv in rvServers.keys) {
      int latency = -1;
      for (final ip in rvServers[rv]!) {
        latency = await _getLatency(ip);
        if (latency >= 0) break; // got a response, no need to try the next IP
      }
      latencyMap[rv] = latency;
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
    logger.info('Client RV latencies: $clientLatencies');
    logger.info('Daemon RV latencies: $daemonLatencies');
    logger.info('Selecting best RV: $bestRv');
    
    return bestRv;
  }
}