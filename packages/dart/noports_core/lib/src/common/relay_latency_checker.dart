import 'dart:io';

import 'package:at_utils/at_logger.dart';

class RelayLatencyChecker {
  static final AtSignLogger logger = AtSignLogger('RelayLatencyChecker');

  static Future<int> _probeLatency(
    String host,
    int port,
    Duration timeout,
  ) async {
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
  ///   "@rv_am": { "ipaddr": "192.0.2.1", "port": 443 },
  ///   "@rv_eu": { "ipaddr": "192.0.2.2", "port": 443 }
  /// }
  /// ```
  ///
  /// Returns a map of RV atSign → latency in milliseconds, or -1 if unreachable.
  static Future<Map<String, int>> measureLatencies(
    Map<String, dynamic> rvServers, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final latencies = <String, int>{};

    await Future.wait(
      rvServers.keys.map((rv) async {
        final addr = rvServers[rv] as Map<String, dynamic>;
        final ip = addr['ipaddr'] as String?;
        final port = addr['port'] as int?;

        if (ip == null || port == null) {
          logger.warning('Missing ipaddr or port for $rv, skipping');
          logger.finer('Received: $rvServers');
          latencies[rv] = -1;
          return;
        }
        latencies[rv] = await _probeLatency(ip, port, timeout);
      }),
    );

    return latencies;
  }
}
