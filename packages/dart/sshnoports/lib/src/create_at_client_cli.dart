import 'dart:io';
import 'package:at_client/at_client.dart';
import 'package:at_onboarding_cli/at_onboarding_cli.dart';
import 'package:noports_core/utils.dart';
import 'package:version/version.dart';
import 'package:path/path.dart' as path;
import 'service_factories.dart';

Future<AtClient> createAtClientCli({
  required String homeDirectory,
  required String atsign,
  required String atKeysFilePath,
  String? storagePath,
  String? pathExtension,
  String subDirectory = '.sshnp',
  String namespace = DefaultArgs.namespace,
  String rootDomain = DefaultArgs.rootDomain,
}) async {
  // Now on to the atPlatform startup
  //onboarding preference builder can be used to set onboardingService parameters
  String pathBase = '$homeDirectory/$subDirectory/$atsign/';
  if (pathExtension != null) {
    pathBase += '$pathExtension${Platform.pathSeparator}';
  }
  storagePath ??= path.normalize('$pathBase/storage');
  AtOnboardingPreference atOnboardingConfig = AtOnboardingPreference()
    ..hiveStoragePath = storagePath
    ..namespace = namespace
    ..downloadPath = path.normalize('$homeDirectory/$subDirectory/files')
    ..isLocalStoreRequired = true
    ..commitLogPath = path.normalize('$storagePath/commitLog')
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
