import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:version/version.dart';
import 'package:path/path.dart' as path;
import 'service_factories.dart';

Future<AtClient> createAtClientCli({
  required String homeDirectory,
  required String atsign,
  required String atKeysFilePath,
  String? pathExtension,
  String subDirectory = '.sshnp',
  String namespace = 'sshnp',
  String rootDomain = 'root.atsign.org',
}) async {
  // Now on to the atPlatform startup
  //onboarding preference builder can be used to set onboardingService parameters
  String pathBase = '$homeDirectory/$subDirectory/$atsign/';
  if (pathExtension != null) {
    pathBase += '$pathExtension${Platform.pathSeparator}';
  }
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = path.normalize('$pathBase/storage')
    ..namespace = namespace
    ..downloadPath = path.normalize('$homeDirectory/$subDirectory/files')
    ..isLocalStoreRequired = true
    ..commitLogPath = path.normalize('$pathBase/storage/commitLog')
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atKeysFilePath
    ..atProtocolEmitted = Version(2, 0, 0)
    ..rootDomain = rootDomain;

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(
      atsign, atOnboardingConfig,
      atServiceFactory: ServiceFactoryWithNoOpSyncService());

  await onboardingService.authenticate();

  return AtClientManager.getInstance().atClient;
}
