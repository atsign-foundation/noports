import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:chalkdart/chalk.dart';

import 'at_pipe_params.dart';
import 'at_pipe_sender.dart';
import 'at_pipe_receiver.dart';

abstract class AtPipe {
  static final _simpleColorCodedHandler = ColorCodedStderrLoggingHandler();

  factory AtPipe.fromArgs(List<String> args) {
    AtSignLogger.defaultLoggingHandler = _simpleColorCodedHandler;
    if (args.isEmpty) {
      throw ArgumentError('At least one argument is required.');
    }

    final params = AtPipeParams.fromArgs(args);
    return params.isSender ? AtPipeSender(params) : AtPipeReceiver(params);
  }

  final AtPipeParams params;
  late final AtClient atClient;
  late final AtSignLogger logger;

  late final CLIBase _cliBase;

  AtPipe(this.params) {
    if (params.verbose) {
      AtSignLogger.root_level = 'INFO';
    }
    if (params.debug) {
      AtSignLogger.root_level = 'FINEST';
    }

    logger = AtSignLogger(' $runtimeType ')..level = 'info';
  }

  @protected
  Future<void> connectAtClient() async {
    _cliBase = CLIBase(
      atSign: params.atSign,
      nameSpace: 'sshnp',
      atRootDomain: params.rootDomain,
      homeDir: getHomeDirectory(throwIfNull: true),
      verbose: params.verbose || params.debug,
      atKeysFilePath: params.atKeysFilePath,
      syncDisabled: true,
      storageDir: standardAtClientStoragePath(
        baseDir: getHomeDirectory(throwIfNull: true)!,
        atSign: params.atSign,
        progName: 'atpipe',
        uniqueID: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
    AtSignLogger.defaultLoggingHandler = _simpleColorCodedHandler;
    await _cliBase.init();
    atClient = _cliBase.atClient;
  }

  Future<int> wrappedMain();
}

class ColorCodedStderrLoggingHandler implements LoggingHandler {
  @override
  void call(record) {
    stderr.write(
      chalk.green(
        '${_getColoredLevel(record.level).padLeft(7)}'
        '|${record.time}'
        '|${record.loggerName}'
        '|${record.message} \n',
      ),
    );
  }

  String _getColoredLevel(Level level) {
    switch (level) {
      case Level.WARNING:
        return chalk.yellow(level.name.toLowerCase());
      case Level.SEVERE:
      case Level.SHOUT:
        return chalk.red(level.name.toLowerCase());
      case Level.INFO:
        return chalk.blueBright(level.name.toLowerCase());
      case Level.FINER:
      case Level.FINEST:
      default:
        return chalk.gray(level.name.toLowerCase());
    }
  }
}
