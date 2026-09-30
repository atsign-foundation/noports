import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:at_utils/at_utils.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;

/// Opens [atsign] from its keyfile, waits for it to come online, and makes it
/// the manager's current client.
///
/// Throws [UnAuthenticatedException] carrying the atServer's reason when it
/// refuses the atSign, and [SecondaryServerConnectivityException] when the
/// client is still offline after [maxConnectAttempts] tries, three seconds
/// apart.
Future<AtClient> createAtClientCli({
  required String atsign,
  required String atKeysFilePath,
  String? passPhrase = '',
  required AtServiceFactory atServiceFactory,
  required String storagePath,
  required String namespace,
  String rootDomain = DefaultArgs.rootDomain,
  int maxConnectAttempts = 5,
}) async {
  atsign = AtUtils.fixAtSign(atsign);
  final AtRootDomain parsedRootDomain = AtRootDomain.parse(rootDomain);

  final AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
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
      keys: FileAtKeysIo(
        filePath: (_) => atKeysFilePath,
        passPhrase: passPhrase,
      ),
      preference: atOnboardingConfig,
      storage: atOnboardingConfig.storageFor(atsign),
      serviceFactory: atServiceFactory,
      lookUps: atOnboardingConfig.lookUps,
    );
  } on AtOpenRefusedException catch (e) {
    throw UnAuthenticatedException('Unable to authenticate $atsign: ${e.message}');
  }

  const retryInterval = Duration(seconds: 3);
  final state = await client.connection.awaitOnline(
    budget: retryInterval * maxConnectAttempts,
    retryInterval: retryInterval,
  );
  if (!state.isOnline) {
    await client.stop();
    throw SecondaryServerConnectivityException(
      '$atsign could not connect to its atServer within $maxConnectAttempts'
      ' attempts: ${state.outcome.name}'
      '${state.cause == null ? '' : ' (${state.cause!.name})'}',
    );
  }

  AtClientManager.getInstance().use(client);
  return client;
}
