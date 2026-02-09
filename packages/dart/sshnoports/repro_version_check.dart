import 'package:noports_core/src/sshnpd/utils/platform_utils.dart';
import 'package:noports_core/version.dart';
import 'dart:io';

Future<void> main() async {
  print('Package Version: $packageVersion');
  print('Platform: ${Platform.operatingSystem}');
  
  try {
    print('Attempting to get current version via PlatformUtils...');
    String version = await PlatformUtils.instance.getCurrentVersion();
    print('Version found: $version');
  } catch (e) {
    print('Caught expected error: $e');
  }
}
