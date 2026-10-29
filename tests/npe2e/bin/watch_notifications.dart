import 'dart:io';

import 'package:args/args.dart';
import 'package:at_client_cli/at_client_cli.dart';
import 'package:at_client/at_client.dart';
import 'package:noports_core/utils.dart' show DefaultArgs;

/// Prints each notification an atSign receives, and how many arrived in each
/// interval, for --seconds counted from when the watcher has connected.
///
/// Needs a --storage-dir of its own, since the default is shared with the
/// other NoPorts programs on the same atSign; it never syncs.
Future<void> main(List<String> args) async {
  final ArgParser parser =
      CLIBase.createArgsParser(
          namespace: DefaultArgs.namespace,
          addLegacyRootDomainArg: false,
        )
        ..addOption('seconds', defaultsTo: '120', help: 'How long to watch')
        ..addOption('interval', defaultsTo: '10', help: 'Seconds per count');
  final ArgResults parsed = parser.parse(args);
  final int? seconds = int.tryParse(parsed['seconds']);
  final int? interval = int.tryParse(parsed['interval']);
  if (parsed['storage-dir'] == null) {
    stderr.writeln('--storage-dir is required\n${parser.usage}');
    exit(2);
  }
  if (seconds == null ||
      interval == null ||
      interval <= 0 ||
      seconds < interval ||
      seconds % interval != 0) {
    stderr.writeln('--seconds must be a positive multiple of --interval');
    exit(2);
  }

  final CLIBase cli = await CLIBase.fromCommandLineArgs([
    ...args,
    if (parsed['never-sync'] != true) '--never-sync',
  ], parser: parser);
  int inInterval = 0;
  int total = 0;
  cli.atClient.notificationService
      .subscribe(regex: '.*', shouldDecrypt: false)
      .listen((AtNotification n) {
        inInterval++;
        total++;
        stdout.writeln('  ${n.from} ${n.key}');
      });

  for (int elapsed = interval; elapsed <= seconds; elapsed += interval) {
    await Future<void>.delayed(Duration(seconds: interval));
    stdout.writeln(
      '${elapsed}s: $inInterval in the last ${interval}s, $total in all',
    );
    inInterval = 0;
  }
  exit(0);
}
