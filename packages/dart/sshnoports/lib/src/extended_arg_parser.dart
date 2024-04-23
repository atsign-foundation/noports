import 'package:args/args.dart';
import 'package:noports_core/sshnp_foundation.dart';

const sshClients = ['openssh', 'dart'];

class DefaultExtendedArgs {
  static const sshClient = SupportedSshClient.openssh;
  static const outputExecutionCommand = false;
}

const sshClientOption = 'ssh-client';
const outputExecutionCommandFlag = 'output-execution-command';

class ExtendedArgParser {
  static ArgParser createArgParser({int? usageLineLength}) {
    final parser = SshnpArg.createArgParser(
      parserType: ParserType.commandLine,
      usageLineLength: usageLineLength,
    );

    parser.addOption(
      sshClientOption,
      help: 'What to use for outbound ssh connections',
      allowed: SupportedSshClient.values.map((e) => e.toString()),
      defaultsTo: DefaultExtendedArgs.sshClient.toString(),
    );

    parser.addFlag(
      outputExecutionCommandFlag,
      abbr: 'x',
      help: 'Output the command that would be executed, and exit',
      defaultsTo: DefaultExtendedArgs.outputExecutionCommand,
      negatable: false,
    );

    return parser;
  }

  final ArgParser parser;
  ArgResults? results;

  ExtendedArgParser({int? usageLineLength})
      : parser = createArgParser(usageLineLength: usageLineLength);

  ArgResults parse(Iterable<String> args) {
    return result = parser.parse(args);
  }

  String get usage => parser.usage;

  List<String> extractCoreArgs(Iterable<String> args) {
    List<String> coreArgs = args.toList();

    if (results == null) {
      results = parse(args);
    }

    if (results!.wasParsed('ssh-client')) {
      final indices = coreArgs.indexed
          .where((element) => element.$2 == '--$sshClientOption')
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

    if (results!.wasParsed(outputExecutionCommandFlag)) {
      coreArgs
          .removeWhere((element) => element == '--$outputExecutionCommandFlag');
      coreArgs.removeWhere((element) => element == '-x');
    }

    return coreArgs;
  }
}
