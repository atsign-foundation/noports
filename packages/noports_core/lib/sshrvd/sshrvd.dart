import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:args/args.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'package:noports_core/common/utils.dart';
import 'package:noports_core/sshrvd/socket_connector.dart';

part 'sshrvd_impl.dart';
part 'sshrvd_params.dart';

abstract class SSHRVD {
  static const String namespace = 'sshrvd';

  abstract final AtSignLogger logger;
  abstract AtClient atClient;
  abstract final String atSign;
  abstract final String homeDirectory;
  abstract final String atKeysFilePath;
  abstract final String managerAtsign;
  abstract final String ipAddress;
  abstract final bool snoop;

  /// true once [init] has completed
  @visibleForTesting
  bool initialized = false;

  factory SSHRVD(
      {
      // final fields
      required AtClient atClient,
      required String atSign,
      required String homeDirectory,
      required String atKeysFilePath,
      required String managerAtsign,
      required String ipAddress,
      required bool snoop}) {
    return SSHRVDImpl(
      atClient: atClient,
      atSign: atSign,
      homeDirectory: homeDirectory,
      atKeysFilePath: atKeysFilePath,
      managerAtsign: managerAtsign,
      ipAddress: ipAddress,
      snoop: snoop,
    );
  }

  static Future<SSHRVD> fromCommandLineArgs(List<String> args,
      {AtClient? atClient,
      FutureOr<AtClient> Function(SSHRVDParams)? atClientGenerator}) async {
    return SSHRVDImpl.fromCommandLineArgs(
      args,
      atClient: atClient,
      atClientGenerator: atClientGenerator,
    );
  }

  Future<void> init();
  Future<void> run();
}
