import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:noports_core/commands.dart';
import 'package:noports_core/utils.dart' show CLILoggingHandler;

enum NoPortsCommand {
  activate('activate'),
  issueKeys('issue-keys');

  final String commandName;

  const NoPortsCommand(this.commandName);

  static NoPortsCommand fromString(String value) {
    try {
      return NoPortsCommand.values
          .firstWhere((cmd) => cmd.commandName == value);
    } catch (e) {
      throw ArgumentError(value);
    }
  }
}

Future<void> main(List<String> args) async {
  displayBanner();
  AtSignLogger.root_level = 'severe';
  AtSignLogger logger =
      AtSignLogger('NoPorts', loggingHandler: CLILoggingHandler())
        ..level = 'info';

  // Check for help flag
  if (args.isEmpty || isHelpFlag(args[0])) {
    printUsage();
    exit(0);
  }

  // Parse command
  final NoPortsCommand command;
  try {
    command = NoPortsCommand.fromString(args[0]);
  } catch (e) {
    logger.shout('Unknown command: ${args[0]}');
    printUsage();
    exit(1);
  }

  int exitCode = 0;
  try {
    switch (command) {
      case NoPortsCommand.activate:
        Activate activate = Activate.fromArgs(args.sublist(1));
        exitCode = await activate.wrappedMain();
        break;
      case NoPortsCommand.issueKeys:
        IssueKeys issueKeys = IssueKeys.fromArgs(args.sublist(1));
        exitCode = await issueKeys.wrappedMain();
        break;
    }
  } on HelpRequestedException {
    printUsage(command: command);
    exit(0);
  } on ArgumentError catch (e) {
    logger.shout(e.message);
    printUsage(command: command);
    exit(2);
  } catch (e) {
    logger.shout(e.toString());
    exit(2);
  }

  exit(exitCode);
}

void printUsage({NoPortsCommand? command}) {
  if (command == null) {
    stderr.writeln(UsageMessages.mainMenu);
    return;
  }

  switch (command) {
    case NoPortsCommand.activate:
      stderr.writeln(UsageMessages.activateHelp);
      break;
    case NoPortsCommand.issueKeys:
      stderr.writeln(UsageMessages.issueKeysHelp);
      break;
  }
}
