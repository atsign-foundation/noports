import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:version/version.dart';

import 'service_factories.dart';

Future<AtClient> createAtClientCli(
    {required String homeDirectory,
    required String atsign,
    String? sessionId,
    required String atKeysFilePath}) async {
  // Now on to the atPlatform startup
  //onboarding preference builder can be used to set onboardingService parameters
  String pathBase = '$homeDirectory/.sshnp/$atsign/';
  if (sessionId != null) {
    pathBase += '$sessionId/';
  }
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath =
        '$pathBase/storage'.replaceAll('/', Platform.pathSeparator)
    ..namespace = 'sshnp'
    ..downloadPath =
        '$homeDirectory/.sshnp/files'.replaceAll('/', Platform.pathSeparator)
    ..isLocalStoreRequired = true
    ..commitLogPath =
        '$pathBase/storage/commitLog'.replaceAll('/', Platform.pathSeparator)
    ..fetchOfflineNotifications = false
    ..atKeysFilePath = atKeysFilePath
    ..atProtocolEmitted = Version(2, 0, 0);

  AtOnboardingService onboardingService = AtOnboardingServiceImpl(
      atsign, atOnboardingConfig,
      atServiceFactory: ServiceFactoryWithNoOpSyncService());

  await onboardingService.authenticate();

  return AtClientManager.getInstance().atClient;
}
