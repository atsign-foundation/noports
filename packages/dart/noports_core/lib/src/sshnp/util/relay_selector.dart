import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import 'package:noports_core/srvd.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_default_channel.dart';
import 'package:noports_core/src/common/relay_latency_checker.dart';
import 'package:uuid/uuid.dart';

class RelaySelector with AtClientBindings {
  @override
  late final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('RelaySelector');

  final String rvServerListUrl =
      'https://atsign-foundation.github.io/noports/standard_relays.json';

  final Map<String, Map<String, dynamic>> rvIpMap = {};

  late Map<String, dynamic> defaultRvList = {};

  RelaySelector(this.atClient);

  /// Selects the best RV atsign for a given connection.
  ///
  /// Measures latency from both the client and the daemon to all known RVs,
  /// then returns the atsign of the RV with the lowest combined average latency.
  ///
  /// If [rvAtSigns] is provided, it will select the best from that list.
  /// Otherwise, it will fetch the standard relays from [rvServerListUrl].
  ///
  /// If [channel] is provided (e.g. reusing an already-created session channel),
  /// it will be used directly. Otherwise a temporary channel is created.
  Future<String> selectBestRelay(
      SshnpParams params, {
        List<Atsign>? rvAtSigns,
        SshnpdChannel? channel,
      }) async {
    List<Atsign> toCheck = [];

    if (rvAtSigns != null && rvAtSigns.isNotEmpty) {
      toCheck = rvAtSigns;
    } else {
      // fetch a list of available RVs from [rvServerListUrl]
      final standardRelaysRaw = await _fetchStandardRelays();
      defaultRvList =
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
          logger.warning('Failed to get IP for $rv: $e');
        }
      }),
    );

    if (rvIpMap.isEmpty) {
      throw StateError('No RV servers could be resolved');
    }

    final clientLatency = await RelayLatencyChecker.measureLatencies(rvIpMap);
    logger.info('Fetched latencies for client -> RV: $clientLatency');

    channel ??= SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: Uuid().v4(),
      namespace: DefaultArgs.namespace,
    );

    final deviceLatency = await channel.fetchDeviceRelayLatencies(rvIpMap);
    logger.info('Fetched latencies for device -> RV: $deviceLatency');
    channel = null;

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
    String regex = 'discover\\.${Srvd.namespace}$rvAtSign';

    late StreamSubscription<AtNotification> subscription;
    subscription = subscribe(regex: regex, shouldDecrypt: true).listen((
      notification,
    ) {
      if (!completer.isCompleted &&
          notification.from == rvAtSign &&
          notification.value != null) {
        final ipAddress = jsonDecode(notification.value!);
        completer.complete(ipAddress);
        subscription.cancel();
      }
    });

    final atKey = AtKey()
      // embed namespace in key
      // namespaceAware=false prevents the client's own namespace being appended
      ..key = 'discover.${Srvd.namespace}'
      ..sharedBy = atClient.getCurrentAtSign()
      ..sharedWith = rvAtSign
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = false);

    await notify(
      atKey,
      'discover',
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

  /// Accepts two maps of RV atsigns to latency in milliseconds, and returns
  /// the atsign of the RV with the lowest combined average latency.
  String _lowestAverageLatency(
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
    return bestRv;
  }
}
