import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:config/config.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/events/events_config.dart';

class EventsParams extends AtsignParams {
  final String homeDirectory;
  final List<Atsign> loggingAtsigns;

  EventsParams({
    required super.atSign,
    required super.atKeysFilePath,
    required super.passPhrase,
    required super.storagePath,
    required super.rootDomain,
    required super.verbose,
    required super.debug,
    required this.homeDirectory,
    required this.loggingAtsigns,
  });

  static EventsParams fromArgs(
    List<String> args, {
    void Function()? helpCallback,
    void Function()? versionCallback,
  }) {
    final Configuration c = Configuration<EventsOption>.resolveNoExcept(
      options: EventsOption.values,
      args: args,
      configBroker: EventsConfigBroker(),
    );

    if (c.value(EventsOption.version)) {
      versionCallback?.call();
    }

    if (c.value(EventsOption.help)) {
      helpCallback?.call();
    }

    if (c.errors.isNotEmpty) {
      throw ArgumentError(c.errors.first);
    }

    final homeDirectory = getHomeDirectory(throwIfNull: true)!;
    final atSign = c.value(EventsOption.atsign).toAtsign();

    return EventsParams(
      atSign: atSign,
      atKeysFilePath:
          c.optionalValue(EventsOption.keyfile) ??
          getDefaultAtKeysFilePath(homeDirectory, atSign),
      passPhrase: c.optionalValue(EventsOption.passPhrase) ?? '',
      storagePath:
          c.optionalValue(EventsOption.storagePath)?.path ??
          standardAtClientStoragePath(
            baseDir: homeDirectory,
            atSign: atSign,
            progName: DefaultArgs.namespace,
            uniqueID: 'single',
          ),
      rootDomain: c.value(EventsOption.rootServer),
      verbose: c.value(EventsOption.verbose),
      debug: c.value(EventsOption.debug),
      homeDirectory: homeDirectory,
      loggingAtsigns: c
          .value(EventsOption.loggingAtsigns)
          .map((atsign) => atsign.toAtsign())
          .toList(),
    );
  }
}
