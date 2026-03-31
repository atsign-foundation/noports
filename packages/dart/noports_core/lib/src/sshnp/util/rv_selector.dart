import 'package:at_client/at_client.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_channel.dart';
import 'package:noports_core/sshnp.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/util/sshnpd_channel/sshnpd_default_channel.dart';
import 'package:noports_core/src/common/srvd_latency_checker.dart';
import 'package:uuid/uuid.dart';

/// Selects the best RV atsign for a given connection.
///
/// Measures latency from both the client and the daemon to all known RVs,
/// then returns the atsign of the RV with the lowest combined average latency.
///
/// If [channel] is provided (e.g. reusing an already-created session channel),
/// it will be used directly. Otherwise a temporary channel is created.
Future<String> selectBestRv(
  AtClient atClient,
  SshnpParams params, {
  SshnpdChannel? channel,
}) async {
  final checker = AtLatencyChecker();

  channel ??= SshnpdDefaultChannel(
    atClient: atClient,
    params: params,
    sessionId: Uuid().v4(),
    namespace: DefaultArgs.namespace,
  );

  final clientLatency = await checker.getRvLatencyMap();
  final deviceLatency = await channel.getRvLatencyDevice();
  channel = null;

  return checker.getBestRv(deviceLatency, clientLatency);
}
