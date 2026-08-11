import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/srvd/build_env.dart';
import 'package:noports_core/src/srvd/srvd_config.dart';

class SrvdParams extends AtsignParams {
  final String homeDirectory;
  final Atsign? managerAtsign;
  final String ipAddress;
  final bool logTraffic;
  final bool perSessionStorage;

  /// Whether to start an isolate where all connections are to the same port
  final bool bind443;

  /// The actual port to bind to - for example in a docker env you may wish
  /// to forward port 443 on the host to some local port in the container
  final int localBindPort443;

  SrvdParams({
    required super.atSign,
    required super.rootDomain,
    required super.passPhrase,
    required super.atKeysFilePath,
    required super.storagePath,
    required super.verbose,
    required super.debug,
    required this.homeDirectory,
    required this.managerAtsign,
    required this.ipAddress,
    required this.logTraffic,
    required this.perSessionStorage,
    required this.bind443,
    required this.localBindPort443,
  });

  static Future<SrvdParams> fromArgs(
    List<String> args, {
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) async {
    // Arg check
    final Configuration c = Configuration<SrvdOption>.resolveNoExcept(
      options: SrvdOption.values,
      args: args,
      configBroker: SrvdConfigBroker(),
    );

    if (c.value(SrvdOption.version)) {
      versionCallback?.call();
    }

    if (c.value(SrvdOption.help)) {
      helpCallback?.call();
    }

    if (c.errors.isNotEmpty) {
      throw ArgumentError(c.errors.first);
    }

    final Atsign atSign = c.value(SrvdOption.atsign).toAtsign();
    String homeDirectory;
    try {
      homeDirectory = getHomeDirectory(throwIfNull: true)!;
    } catch (e) {
      throw ArgumentError(e);
    }

    return SrvdParams(
      atSign: atSign,
      homeDirectory: homeDirectory,
      atKeysFilePath:
          c.optionalValue(SrvdOption.keyfile) ??
          getDefaultAtKeysFilePath(homeDirectory, atSign),
      passPhrase: c.optionalValue(SrvdOption.passPhrase) ?? '',
      managerAtsign: c.optionalValue(SrvdOption.manager)?.toAtsign(),
      ipAddress: c.value(SrvdOption.ipAddress),
      verbose: c.value(SrvdOption.verbose),
      logTraffic: BuildEnv.enableSnoop && c.value(SrvdOption.logTraffic),
      rootDomain: c.value(SrvdOption.rootServer),
      perSessionStorage: c.value(SrvdOption.perSessionStorage),
      bind443: c.value(SrvdOption.bind443),
      localBindPort443: c.value(SrvdOption.bindPort),
      debug: c.value(SrvdOption.debug),
      storagePath:
          c.optionalValue(SrvdOption.storagePath)?.path ??
          standardAtClientStoragePath(
            baseDir: homeDirectory,
            atSign: atSign,
            progName: 'srvd',
            uniqueID: 'srvd',
          ),
    );
  }
}
