import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';

abstract class Srvd {
  static const String namespace = 'sshrvd';

  abstract final AtSignLogger logger;
  abstract AtClient atClient;
  abstract final String atSign;
  abstract final String homeDirectory;
  abstract final String atKeysFilePath;
  abstract final String managerAtsign;
  abstract final String ipAddress;
  abstract final bool logTraffic;
  bool verbose = false;

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  static Future<Srvd> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SrvdParams)? atClientGenerator,
      void Function(Object, StackTrace)? usageCallback}) async {
    return SrvdImpl.fromCommandLineArgs(args,
        atClient: atClient,
        atClientGenerator: atClientGenerator,
        usageCallback: usageCallback);
  }

  Future<void> init();
  Future<void> run();
}
