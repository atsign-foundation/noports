import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:noports_core/commands.dart';
import 'package:sshnoports/src/print_version.dart';

enum NoPortsCommand {
  activate('activate'),
  issueKeys('issue-keys');

  final String commandName;

  const NoPortsCommand(this.commandName);

  static NoPortsCommand parse(String value) {
    return NoPortsCommand.values.firstWhere((cmd) => cmd.commandName == value);
  }

  static NoPortsCommand? tryParse(String value) {
    try {
      return parse(value);
    } catch (e) {
      return null;
    }
  }
}

Future<void> main(List<String> args) async {
  final logger = setupLogging();

  if (args.isEmpty) {
    logger.shout('At least one argument is required');
    stderr.writeln('\n');
    printUsage();
    exit(1);
  }

  // Display help if requested
  if (isHelpFlag(args[0])) {
    printUsage();
    exit(0);
  }

  // Parse command
  final command = NoPortsCommand.tryParse(args[0]);
  if (command == null) {
    logger.shout('Invalid command: ${args[0]}');
    stderr.writeln('\n');
    printUsage();
    exit(1);
  }

  try {
    final commandArgs = args.sublist(1);
    int exitCode = 0;

    switch (command) {
      case NoPortsCommand.activate:
        final activateImpl = Activate.fromArgs(commandArgs);
        exitCode = await activateImpl.wrappedMain();
        break;
      case NoPortsCommand.issueKeys:
        final issueKeysImpl = IssueKeys.fromArgs(commandArgs);
        exitCode = await issueKeysImpl.wrappedMain();
        break;
    }
    exit(exitCode);
  } on HelpRequestedException {
    printUsage(command: command);
    exit(0);
  } on ArgumentError catch (e) {
    logger.shout(e.message);
    stderr.writeln('\n');
    printUsage(command: command);
    exit(1);
  } catch (e) {
    logger.shout(e.toString());
    exit(2);
  }
}

void printUsage({NoPortsCommand? command}) {
  if (command == null) {
    stderr.writeln(UsageMessages.mainMenu);
  } else {
    switch (command) {
      case NoPortsCommand.activate:
        stderr.writeln(UsageMessages.activateHelp);
        break;
      case NoPortsCommand.issueKeys:
        stderr.writeln(UsageMessages.issueKeysHelp);
        break;
    }
  }
  printVersion();
  stderr.write('\n');
  return;
}

AtSignLogger setupLogging() {
  displayBanner();
  AtSignLogger.root_level = 'severe';
  return AtSignLogger('NoPorts', loggingHandler: CLILoggingHandler())
    ..level = 'info';
}
