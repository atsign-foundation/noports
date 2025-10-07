/// This file contains all of the dart:io calls in noports_core
/// All io used should be wrapped for the sake of testing and compatibility
library io_types;

import 'dart:io' show Process, ProcessResult, ProcessStartMode;
import 'package:meta/meta.dart';

export 'dart:io'
    show Platform, Process, ProcessStartMode, ServerSocket, InternetAddress;
export 'package:file/file.dart';
export 'package:file/local.dart' show LocalFileSystem;

@internal
typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
});

@internal
typedef ProcessStarter = Future<Process> Function(
  String executable,
  List<String> arguments, {
  bool runInShell,
  ProcessStartMode mode,
});
