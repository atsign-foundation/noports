import 'dart:io';

import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/src/noports_cli/activate/np_activate.dart';
import 'package:sshnoports/src/noports_cli/issue_keys/np_issue_keys.dart';
import 'package:sshnoports/src/noports_cli/util/np_utils.dart';
import 'package:sshnoports/src/noports_cli/util/usage_messages.dart';

enum NoportsCommand {
  activate('activate'),
  issueKeys('issue-keys');

  final String commandName;

  const NoportsCommand(this.commandName);

  static NoportsCommand fromString(String value) {
    try {
      return NoportsCommand.values
          .firstWhere((cmd) => cmd.commandName == value);
    } catch (e) {
      throw ArgumentError('Invalid command: $value');
    }
  }
}

final NPActivate npActivate = NPActivateImpl();
final NPIssueKeys issueKeys = NPIssueKeysImpl();

Future<void> main(List<String> args) async {
  AtSignLogger.root_level = 'SEVERE';
  displayBanner();
  int exc = 0;

  if (args.isEmpty) {
    writeError('You must supply a command');
    printUsage();
    exit(1);
  }

  final command = NoportsCommand.fromString(args[0]);
  if (args.length == 1) {
    writeError('You must supply an argument string');
    printUsage(command: command);
    exit(1);
  }

  try {
    switch (command) {
      case NoportsCommand.activate:
        exc = await NPActivateImpl().wrappedMain(args);
        break;
      case NoportsCommand.issueKeys:
        exc = await NPIssueKeysImpl().wrappedMain(args);
        break;
    }
  } on ArgumentError catch (e) {
    stderr.writeln();
    writeError(e.toString());
    stderr.writeln();
    printUsage(command: command);
    stderr.writeln();
    exit(2);
  } catch (e) {
    /// ToDo: parse exception message to remove unnecessary Exception prefixes
    writeError(e.toString());
    stderr.writeln();
    stderr.writeln('Please try again or contact support@atsign.com');
    stderr.writeln();
    exit(2);
  }
  exit(exc);
}

void printUsage({NoportsCommand? command}) {
  if (command == null) {
    stdout.writeln(UsageMessages.mainMenu);
    return;
  }
  switch (command) {
    case NoportsCommand.activate:
      stdout.writeln(UsageMessages.activateMenu);
      break;
    case NoportsCommand.issueKeys:
      stdout.writeln(UsageMessages.issueKeys);
      break;
  }
}
