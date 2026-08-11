import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/npa/npa_config.dart';

class NPAParams extends AtsignParams {
  final String homeDirectory;
  final Atsign? eventLoggingAtsign;

  Atsign get policyAtsign => atSign;

  NPAParams({
    required super.atSign,
    required super.atKeysFilePath,
    required super.passPhrase,
    required super.storagePath,
    required super.rootDomain,
    required super.verbose,
    required super.debug,
    required this.homeDirectory,
    required this.eventLoggingAtsign,
  });

  static Future<NPAParams> fromArgs(
    List<String> args, {
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) async {
    final Configuration c = Configuration<NPAOption>.resolveNoExcept(
      options: NPAOption.values,
      args: args,
      configBroker: NPAConfigBroker(),
    );

    if (c.value(NPAOption.version)) {
      versionCallback?.call();
    }

    if (c.value(NPAOption.help)) {
      helpCallback?.call();
    }

    if (c.errors.isNotEmpty) {
      throw ArgumentError(c.errors.first);
    }

    final Atsign policyAtsign = c.value(NPAOption.atsign).toAtsign();
    final String homeDirectory = getHomeDirectory(throwIfNull: true)!;

    return NPAParams(
      atSign: policyAtsign,
      atKeysFilePath:
          c.optionalValue(NPAOption.keyfile) ??
          getDefaultAtKeysFilePath(homeDirectory, policyAtsign),
      passPhrase: c.optionalValue(NPAOption.passPhrase) ?? '',
      verbose: c.value(NPAOption.verbose),
      debug: c.value(NPAOption.debug),
      rootDomain: c.value(NPAOption.rootServer),
      homeDirectory: homeDirectory,
      eventLoggingAtsign:
          c.optionalValue(NPAOption.eventLoggingAtsign)?.toAtsign(),
      storagePath:
          c.optionalValue(NPAOption.storagePath)?.path ??
          standardAtClientStoragePath(
            baseDir: homeDirectory,
            atSign: policyAtsign,
            progName: '.${DefaultArgs.namespace}',
            uniqueID: 'single',
          ),
    );
  }
}
