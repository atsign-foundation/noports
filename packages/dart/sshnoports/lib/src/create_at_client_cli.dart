import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;

/// Opens [atsign] from its keyfile, waits for it to come online, and makes it
/// the manager's current client.
///
/// Throws [UnAuthenticatedException] carrying the atServer's reason when it
/// refuses the atSign, whether on this device's first open or on a later
/// one; [SecondaryNotFoundException] when the atDirectory has no atServer for
/// it; and [SecondaryServerConnectivityException] when the client is still
/// offline [onlineBudget] after its first attempt, retrying every three
/// seconds.
///
/// [posture] is how far into the post-quantum rollout the client runs; null
/// means whatever the at_client this was built against defaults to.
Future<AtClient> createAtClientCli({
  required String atsign,
  required String atKeysFilePath,
  String? passPhrase = '',
  required AtServiceFactory atServiceFactory,
  required String storagePath,
  required String namespace,
  String rootDomain = DefaultArgs.rootDomain,
  Duration onlineBudget = const Duration(seconds: 15),
  PqPosture? posture,
}) async {
  atsign = AtUtils.fixAtSign(atsign);
  final AtRootDomain parsedRootDomain = AtRootDomain.parse(rootDomain);

  final AtOnboardingPreference atOnboardingConfig = (posture == null
      ? AtOnboardingPreference()
      : AtOnboardingPreference(posture: posture))
    ..storagePath = storagePath
    ..namespace = namespace
    ..downloadPath = path.normalize('$storagePath/downloads')
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atKeysFilePath
    ..passPhrase = passPhrase
    ..rootDomain = parsedRootDomain.rootDomain
    ..rootPort = parsedRootDomain.rootPort;

  // NOTE open refuses while a client for the atSign is live in this process
  for (final live in AtClientImpl.liveClientsFor(atsign)) {
    await live.stop();
  }

  final AtClient client;
  try {
    client = await Atsign(atsign).open(
      keys:
          FileAtKeysIo(filePath: (_) => atKeysFilePath, passPhrase: passPhrase),
      preference: atOnboardingConfig,
      storage: atOnboardingConfig.storageFor(atsign),
      serviceFactory: atServiceFactory,
      lookUps: atOnboardingConfig.lookUps,
    );
  } on AtOpenRefusedException catch (e) {
    if (e.state.cause == AtConnectionCause.noAtServer) {
      throw SecondaryNotFoundException(
        '$atsign is not in the atDirectory at $rootDomain: check the atSign,'
        ' and that it has been activated',
      );
    }
    throw UnAuthenticatedException(
      'Unable to authenticate $atsign: ${e.message}',
    );
  }

  await onlineOrThrow(client, atsign, onlineBudget);
  AtClientManager.getInstance().use(client);
  return client;
}

/// Waits up to [onlineBudget] for [client] to come online, retrying every
/// three seconds. Stops the client and throws [UnAuthenticatedException]
/// with the atServer's reason when it is refused, or
/// [SecondaryServerConnectivityException] when it is still offline.
Future<void> onlineOrThrow(
  AtClient client,
  String atsign,
  Duration onlineBudget,
) async {
  final state = await client.connection.awaitOnline(
    budget: onlineBudget,
    retryInterval: const Duration(seconds: 3),
  );
  if (state.isOnline) return;

  await client.stop();
  final reason = '${state.cause == null ? '' : ' (${state.cause!.name})'}'
      '${state.error == null ? '' : ': ${state.error}'}';
  if (state.isRefused) {
    throw UnAuthenticatedException(
      'Unable to authenticate $atsign: the atServer refused it$reason',
    );
  }
  throw SecondaryServerConnectivityException(
    '$atsign could not connect to its atServer within'
    ' ${onlineBudget.inSeconds} seconds: ${state.outcome.name}$reason',
  );
}
