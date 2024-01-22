import 'package:args/args.dart';
import 'package:noports_core/sshnp_foundation.dart';

const sshClients = ['openssh', 'dart'];

class DefaultExtendedArgs {
  static const sshClient = SupportedSshClient.openssh;
  static const legacyDaemon = false;
  static const outputExecutionCommand = false;
}

const xFlag = 'output-execution-command';

class ExtendedArgParser {
  static ArgParser createArgParser() {
    final parser = SshnpArg.createArgParser(parserType: ParserType.commandLine);

    parser.addOption(
      'ssh-client',
      help: 'What to use for outbound ssh connections',
      allowed: SupportedSshClient.values.map((e) => e.toString()),
      defaultsTo: DefaultExtendedArgs.sshClient.toString(),
    );

    parser.addFlag(
      'legacy-daemon',
      help: 'Request is to a legacy (< 4.0.0) noports daemon',
      defaultsTo: DefaultExtendedArgs.legacyDaemon,
      negatable: false,
    );

    parser.addFlag(
      xFlag,
      abbr: 'x',
      help: 'Output the command that would be executed, and exit',
      defaultsTo: DefaultExtendedArgs.outputExecutionCommand,
      negatable: false,
    );
    return parser;
  }

  final ArgParser parser;
  ArgResults? results;

  ExtendedArgParser() : parser = createArgParser();

  ArgResults parse(Iterable<String> args) {
    return results = parser.parse(args);
  }

  String get usage => parser.usage;

  List<String> extractCoreArgs(Iterable<String> args) {
    List<String> coreArgs = args.toList();

    if (results == null) {
      parse(args);
    }

    if (results!.wasParsed('ssh-client')) {
      final indices = coreArgs.indexed
          .where((element) => element.$2 == '--ssh-client')
          .map((e) => e.$1)
          .toList();

      // must remove from back to front, otherwise we will change the indices
      // of elements while trying to remove them
      //
      // i.e. if 1 and 9 both need to be removed, then removing 1 first
      // will cause 9 to become 8, and subsequently 10 to become 9,
      // meaning that the wrong item is removed for position 9
      for (int i in indices.reversed) {
        coreArgs.removeAt(i); // remove the option e.g. --ssh-client
        coreArgs.removeAt(i); // remove the value e.g. "openssh"
      }
    }

    if (results!.wasParsed('legacy-daemon')) {
      coreArgs.removeWhere((element) => element == '--legacy-daemon');
    }

    return coreArgs;
  }
}
