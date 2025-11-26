import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate.dart';
import 'package:sshnoports/src/noports_cli/issue_keys/np_issue_keys.dart';
import 'package:sshnoports/src/noports_cli/util/cli_logging_handler.dart';
import 'package:sshnoports/src/noports_cli/util/np_utils.dart';
import 'package:sshnoports/src/noports_cli/util/usage_messages.dart';

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
      throw ArgumentError('Invalid command: $value');
    }
  }
}

AtSignLogger logger =
    AtSignLogger('NoPorts', loggingHandler: CLILoggingHandler());

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'severe';
  logger.level = 'info';
  displayBanner();
  int exc = 0;

  if (args.isEmpty) {
    logger.shout('You must supply a command');
    printUsage();
    exit(1);
  }

  final command = NoPortsCommand.fromString(args[0]);

  try {
    switch (command) {
      case NoPortsCommand.activate:
        // sublist(1) ensures the first element is not propagated further
        NPActivate activate = NPActivate.create(args.sublist(1));
        exc = await activate.wrappedMain();
        break;
      case NoPortsCommand.issueKeys:
        NPIssueKeys issueKeys = await NPIssueKeys.create(args.sublist(1));
        exc = await issueKeys.wrappedMain();
        break;
    }
  } on ArgumentError catch (e) {
    logger.shout(e.toString());
    printUsage(command: command);
    exit(2);
  } catch (e) {
    logger.shout(e.toString());
    exit(2);
  }
  exit(exc);
}

void printUsage({NoPortsCommand? command}) {
  if (command == null) {
    logger.shout(UsageMessages.mainMenu);
    return;
  }
  switch (command) {
    case NoPortsCommand.activate:
      logger.shout(UsageMessages.activateMenu);
      break;
    case NoPortsCommand.issueKeys:
      logger.shout(UsageMessages.issueKeys);
      break;
  }
}
