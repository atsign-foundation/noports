import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:npt_flutter/constants.dart';
import 'package:path_provider/path_provider.dart';

class AtClientMethods {
  static Future<AtClientPreference> loadAtClientPreference(String rootDomain) async {
    var dir = await getApplicationSupportDirectory();

    return AtClientPreference()
      ..rootDomain = rootDomain
      ..namespace = Constants.namespace
      ..hiveStoragePath = dir.path
      ..commitLogPath = dir.path
      ..isLocalStoreRequired = true;
  }
}
