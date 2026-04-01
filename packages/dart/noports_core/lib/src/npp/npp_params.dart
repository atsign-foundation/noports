import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/npp/npp_config.dart';

class NPPParams extends AtsignParams {
  final String homeDirectory;
  final String baseNamespace;
  final String domainNamespace;
  final String persistenceMethod;
  final List<Atsign> managerAllowList;
  final Atsign? eventLoggingAtSign;
  final String? policyDirectory;

  NPPParams({
    required super.atSign,
    required super.rootDomain,
    required super.passPhrase,
    required super.atKeysFilePath,
    required super.storagePath,
    required super.verbose,
    required super.debug,
    required this.homeDirectory,
    required this.baseNamespace,
    required this.domainNamespace,
    required this.persistenceMethod,
    required this.managerAllowList,
    required this.eventLoggingAtSign,
    required this.policyDirectory,
  });

  factory NPPParams.fromArgs(
    List<String> args, {
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) {
    final Configuration c = Configuration<NPPOption>.resolveNoExcept(
      options: NPPOption.values,
      args: args,
      configBroker: NPPConfigBroker(),
    );

    if (c.value(NPPOption.version)) {
      versionCallback?.call();
    }

    if (c.value(NPPOption.help)) {
      helpCallback?.call();
    }

    if (c.errors.isNotEmpty) {
      throw ArgumentError(c.errors.first);
    }

    final homeDirectory = getHomeDirectory(throwIfNull: true)!;
    final atSign = c.value(NPPOption.atsign).toAtsign();
    final baseNamespace = c.value(NPPOption.baseNamespace);

    return NPPParams(
      atSign: atSign,
      rootDomain: c.value(NPPOption.rootServer),
      passPhrase: c.optionalValue(NPPOption.passPhrase) ?? '',
      atKeysFilePath:
          c.optionalValue(NPPOption.keyfile) ??
          getDefaultAtKeysFilePath(homeDirectory, atSign),
      storagePath:
          c.optionalValue(NPPOption.storagePath)?.path ??
          standardAtClientStoragePath(
            baseDir: homeDirectory,
            atSign: atSign,
            progName: baseNamespace,
            uniqueID: 'single',
          ),
      verbose: c.value(NPPOption.verbose),
      debug: c.value(NPPOption.debug),
      homeDirectory: homeDirectory,
      baseNamespace: baseNamespace,
      domainNamespace: c.value(NPPOption.domainNamespace),
      persistenceMethod: c.value(NPPOption.persistenceMethod),
      managerAllowList:
          c.optionalValue(NPPOption.managerAllowList)
              ?.map((atsign) => atsign.toAtsign())
              .toList() ??
          [atSign],
      eventLoggingAtSign:
          c.optionalValue(NPPOption.eventLoggingAtsign)?.toAtsign(),
      policyDirectory: c.optionalValue(NPPOption.policyDirectory)?.path,
    );
  }
}
