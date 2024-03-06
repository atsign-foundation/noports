import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final packageInfo = StateProvider<PackageInfo>(
    (ref) => PackageInfo(appName: 'Unknown', packageName: 'Unknown', version: 'Unknown', buildNumber: 'Unknown'));
