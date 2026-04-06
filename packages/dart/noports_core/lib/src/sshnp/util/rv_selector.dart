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
import 'package:noports_core/src/common/srvd_latency_checker.dart';
import 'package:uuid/uuid.dart';

class RvSelector with AtClientBindings {
  @override
  late final AtClient atClient;

  @override
  final AtSignLogger logger = AtSignLogger('RvSelector');

  static final AtSignLogger _staticLogger = AtSignLogger('RvSelector');

  static const String rvServerListUrl =
      'https://atsign-foundation.github.io/noports/standard_relays.json';

  final Map<String, Map<String, dynamic>> rvIpMap = {};

  RvSelector(this.atClient);

  /// Fetches the RV servers map from [rvServerListUrl].
  /// Returns a map of RV atSign → list of IP/hostname strings.
  /// Throws if the URL is unreachable or returns a non-200 status.
  static Future<Map<String, dynamic>> _fetchRvServers() async {
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
      _staticLogger.warning('Failed to fetch RV list: $e');
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<Map<String, dynamic>> _getIpAddress(AtClient atClient, Atsign rvAtSign) async {
    Completer<Map<String, dynamic>> completer = Completer();

    final String fixedRvAtSign = AtUtils.fixAtSign(rvAtSign.toString());
    final String clientAtSign = AtUtils.fixAtSign(atClient.getCurrentAtSign()!);

    // The srvd will respond with a key 'discover.sshrvd' sharedBy the srvd
    // e.g. @client:discover.sshrvd@rv_am
    String regex = 'discover\\.${Srvd.namespace}$fixedRvAtSign';

    late StreamSubscription<AtNotification> subscription;
    subscription = subscribe(regex: regex, shouldDecrypt: true)
        .listen((notification) {
      if (!completer.isCompleted &&
          notification.from == fixedRvAtSign &&
          notification.value != null) {
        final ipAddress = jsonDecode(notification.value!);
        completer.complete(ipAddress);
        subscription.cancel();
      }
    });

    final atKey = AtKey()
      // embed namespace in key, matching the request_ports convention:
      // namespaceAware=false prevents the client's own namespace being appended
      ..key = 'discover.${Srvd.namespace}'
      ..sharedBy = clientAtSign
      ..sharedWith = fixedRvAtSign
      ..metadata = (Metadata()
        ..isPublic = false
        ..isEncrypted = true
        ..namespaceAware = false);

    await notify(
      atKey,
      'discover',
      checkForFinalDeliveryStatus: false,
      waitForFinalDeliveryStatus: false,
      ttln: Duration(minutes: 1),
    );

    return completer.future.timeout(
      Duration(seconds: 10),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException('Timed out waiting for srvd response from $rvAtSign');
      },
    );
  }

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
  Future<String> selectBestRv(
    SshnpParams params, {
    List<Atsign>? rvAtSigns,
    SshnpdChannel? channel,
  }) async {
    final checker = AtLatencyChecker();

    List<Atsign> toCheck = [];
    if (rvAtSigns != null && rvAtSigns.isNotEmpty) {
      toCheck = rvAtSigns;
    } else {
      // fetch a list of available RVs from [rvServerListUrl]
      final standardRelaysRaw = await _fetchRvServers();
      final Map<String, dynamic> rvServers = standardRelaysRaw['standard_relays'] as Map<String, dynamic>;
      toCheck = rvServers.keys.map((s) => s.toAtsign()).toList();
    }
    logger.shout('RV servers to be Latency-checked: $toCheck');

    // fetch IP for each RV in parallel
    await Future.wait(toCheck.map((rv) async {
      try {
        final ipInfo = await _getIpAddress(atClient, rv);
        rvIpMap[rv.toString()] = ipInfo;
        logger.shout('Got IP for $rv: $ipInfo');
      } catch (e) {
        logger.warning('Failed to get IP for $rv: $e');
      }
    }));

    if (rvIpMap.isEmpty) {
      throw StateError('No RV servers could be resolved');
    }

    channel ??= SshnpdDefaultChannel(
      atClient: atClient,
      params: params,
      sessionId: Uuid().v4(),
      namespace: DefaultArgs.namespace,
    );

    final clientLatency = await checker.getRvLatencyMap(rvIpMap);
    logger.shout('Latency RV-Client: $clientLatency');
    final deviceLatency = await channel.getRvLatencyDevice(rvIpMap);
    logger.shout('Latency Device-RV: $deviceLatency');
    channel = null;

    return checker.getBestRv(deviceLatency, clientLatency);
  }
}
