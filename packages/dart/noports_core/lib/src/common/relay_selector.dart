import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/common/relay_latency_checker.dart';

class RelaySelector with AtClientBindings {
  @override
  late final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('RelaySelector');

  final String clientAtSign;
  final String sshnpdAtSign;
  final String device;
  final String rootDomain;

  /// ToDo: this needs to be constructed using the root address
  final String rvServerListUrl =
      'https://atsign-foundation.github.io/noports/standard_relays.json';

  final Map<String, Map<String, dynamic>> rvIpMap = {};

  RelaySelector({
    required this.atClient,
    required this.clientAtSign,
    required this.sshnpdAtSign,
    required this.device,
    required this.rootDomain,
  }) {
    this.atClient = atClient;
  }

  /// Selects the best RV atsign for a given connection.
  ///
  /// Measures latency from both the client and the daemon to all known RVs,
  /// then returns the atsign of the RV with the lowest combined average latency.
  ///
  /// If [rvAtSigns] is provided, it will select the best from that list.
  /// Otherwise, it will fetch the standard relays from [rvServerListUrl].
  Future<String> selectBestRelay({List<Atsign>? rvAtSigns}) async {
    List<Atsign> toCheck = [];

    if (rvAtSigns != null && rvAtSigns.isNotEmpty) {
      toCheck = rvAtSigns;
    } else {
      // fetch a list of available RVs from [rvServerListUrl]
      final standardRelaysRaw = await _fetchStandardRelays();
      final defaultRvList =
          standardRelaysRaw['standard_relays'] as Map<String, dynamic>;
      toCheck = defaultRvList.keys.map((s) => s.toAtsign()).toList();
    }
    logger.info('Checking latency for RVs: $toCheck');

    // fetch IP for each RV in parallel
    await Future.wait(
      toCheck.map((rv) async {
        try {
          final ipInfo = await _requestRelayIpAddress(rv);
          rvIpMap[rv.toString()] = ipInfo;
        } catch (e) {
          logger.warning('Failed to get IP/Port for $rv: $e');
        }
      }),
    );

    if (rvIpMap.isEmpty) {
      throw StateError('No RV servers could be resolved');
    }

    //Start device latency fetch concurrently while we measure the client latency
    final deviceLatencyFuture = _fetchDeviceLatencies(rvIpMap);

    final clientLatency = await RelayLatencyChecker.measureLatencies(rvIpMap);
    logger.info('Fetched latencies for client -> RV: $clientLatency');

    final deviceLatency = await deviceLatencyFuture;
    logger.info('Fetched latencies for device -> RV: $deviceLatency');

    return _lowestAverageLatency(deviceLatency, clientLatency);
  }

  /// Fetches the RV servers map from [rvServerListUrl].
  /// Returns a map of RV atSign → list of IP/hostname strings.
  /// Throws if the URL is unreachable or returns a non-200 status.
  ///
  /// Expected format from the URL:
  /// ```json
  /// { "standard_relays": { "@rv_am": {...}, "@rv_eu": {...} } }
  /// ```
  Future<Map<String, dynamic>> _fetchStandardRelays() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(rvServerListUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return jsonDecode(body) as Map<String, dynamic>;
      }
      throw StateError(
        'Unexpected status ${response.statusCode} fetching RV list',
      );
    } catch (e) {
      logger.warning('Failed to fetch RV list: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _requestRelayIpAddress(Atsign rvAtSign) async {
    Completer<Map<String, dynamic>> completer = Completer();

    // The srvd will respond with a key 'discover.sshrvd' sharedBy the srvd
    // e.g. @client:discover.sshrvd@rv_am
    String regex = 'discover_response\\.${Srvd.namespace}$rvAtSign';

    late StreamSubscription<AtNotification> subscription;
    subscription = subscribe(regex: regex, shouldDecrypt: true).listen((
      notification,
    ) {
      if (!completer.isCompleted &&
          notification.from == rvAtSign &&
          notification.value != null) {
        final discoverResponse = jsonDecode(notification.value!);
        completer.complete(discoverResponse);
        subscription.cancel();
      }
    });

    final atKey = AtKey()
      // embed namespace in key
      // namespaceAware=false prevents the client's own namespace being appended
      ..key = 'discover_request.${Srvd.namespace}'
      ..sharedBy = atClient.getCurrentAtSign()
      ..sharedWith = rvAtSign
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = false);

    Map<String, dynamic> discoverItems = {
      'items': ['ipaddr', 'port'],
    };
    await notify(
      atKey,
      jsonEncode(discoverItems),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(seconds: 10),
    );

    return completer.future.timeout(
      Duration(seconds: 10),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException(
          'Timed out waiting for discover response from $rvAtSign',
        );
      },
    );
  }

  /// Sends [rvServers] to the device daemon and waits for it to respond with
  /// its measured latency to each RV. Uses this selector's own AtClientBindings
  /// directly, avoiding the need to create and initialize a full SshnpdChannel.
  Future<Map<String, int>> _fetchDeviceLatencies(
    Map<String, dynamic> rvServers,
  ) async {
    final completer = Completer<Map<String, int>>();
    final regex = 'relay_latency_response.$device.${DefaultArgs.namespace}';

    late StreamSubscription<AtNotification> subscription;
    subscription = subscribe(regex: regex, shouldDecrypt: true).listen((
      notification,
    ) {
      logger.info(
        'Received relay latencies from device: ${notification.value}',
      );
      if (notification.from == sshnpdAtSign && !completer.isCompleted) {
        try {
          final Map<String, dynamic> raw = jsonDecode(notification.value!);
          completer.complete(Map<String, int>.from(raw));
        } catch (e) {
          logger.warning('Failed to decode relay latencies from device: $e');
          logger.finer('Response from device: ${notification.value}');
          completer.completeError(
            FormatException(
              'Malformed latency check response from $sshnpdAtSign',
            ),
          );
        } finally {
          subscription.cancel();
        }
      }
    });

    await notify(
      AtKey()
        ..key = 'relay_latency_request.$device'
        ..namespace = DefaultArgs.namespace
        ..sharedBy = clientAtSign
        ..sharedWith = sshnpdAtSign,
      jsonEncode(rvServers),
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    return completer.future.timeout(
      Duration(minutes: 1),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException(
          'Timeout waiting for relay latencies from device',
        );
      },
    );
  }

  /// Accepts two maps of RV atsigns to latency in milliseconds, and returns
  /// the atsign of the RV with the lowest combined average latency.
  Atsign _lowestAverageLatency(
    Map<String, int> daemonLatencies,
    Map<String, int> clientLatencies,
  ) {
    String? bestRv;
    double bestAverage = double.infinity;

    for (final rv in daemonLatencies.keys) {
      final d = daemonLatencies[rv] ?? -1;
      final c = clientLatencies[rv] ?? -1;
      if (d == -1 || c == -1) continue; // skip unreachable RVs

      final average = (d + c) / 2;
      if (average < bestAverage) {
        bestAverage = average;
        bestRv = rv;
      }
    }

    if (bestRv == null) {
      throw StateError('No reachable RV found');
    }

    logger.info('Selecting fastest RV: $bestRv');
    return bestRv.toAtsign();
  }
}
