import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:meta/meta.dart';
import 'package:chalkdart/chalk.dart';

import 'at_pipe_params.dart';
import 'at_pipe_sender.dart';
import 'at_pipe_receiver.dart';

abstract class AtPipe {
  factory AtPipe.fromArgs(List<String> args) {
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

    logger = AtSignLogger(
      ' $runtimeType ',
      loggingHandler: ColorCodedStderrLoggingHandler(),
    )..level = 'info';
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
      storageDir: standardAtClientStoragePath(
        baseDir: getHomeDirectory(throwIfNull: true)!,
        atSign: params.atSign,
        progName: 'atpipe',
        uniqueID: DateTime.now().microsecondsSinceEpoch.toString(),
      ),
    );
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
        '${record.level.name}|${record.time}|${record.loggerName}|${record.message} \n',
      ),
    );
  }
}
