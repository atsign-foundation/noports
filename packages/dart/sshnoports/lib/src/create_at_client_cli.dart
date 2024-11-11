import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:noports_core/utils.dart';
import 'package:path/path.dart' as path;
import 'package:version/version.dart';

Future<AtClient> createAtClientCli({
  required String atsign,
  required String atKeysFilePath,
  required AtServiceFactory atServiceFactory,
  required String storagePath,
  required String namespace,
  String rootDomain = DefaultArgs.rootDomain,
    String? passPhrase = ''}) async {
  // Now on to the atPlatform startup
  //onboarding preference builder can be used to set onboardingService parameters
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = storagePath
    ..namespace = namespace
    ..downloadPath = path.normalize('$storagePath/downloads')
    ..isLocalStoreRequired = true
    ..commitLogPath = path.normalize('$storagePath/commitLog')
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atKeysFilePath
    ..atProtocolEmitted = Version(2, 0, 0)
    ..rootDomain = rootDomain
    ..passPhrase = passPhrase;

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(
      atsign, atOnboardingConfig,
      atServiceFactory: atServiceFactory);

  await onboardingService.authenticate();

  return AtClientManager.getInstance().atClient;
}
