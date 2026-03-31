import 'dart:io';
import 'package:noports_core/src/config/shared_options.dart';
import 'package:noports_core/src/sshnpd/sshnpd_params.dart';
import 'package:noports_core/src/srvd/srvd_params.dart';

File defaultConfigFilePath<T extends AtsignParams>() {
  String binary = switch (T) {
    const (SshnpdParams) => 'sshnpd',
    const (SrvdParams) => 'srvd',
    _ => throw ArgumentError("parameter type doesn't exist: $T"),
  };
  switch (Platform.operatingSystem) {
    case "windows":
      final programData = Platform.environment['ProgramData'];
      return File("$programData/NoPorts/$binary.yaml");
    case "macos":
      return File("/Library/Application Support/NoPorts/$binary.yaml");
    default:
      return File("/etc/noports/$binary.yaml");
  }
}

///Read config for a certain parameter type
///Throws errors if missing config or necessary details
T readConfig<T extends AtsignParams>() {
  //using empty list as args to force the broker to use the config
  return switch (T) {
        const (SshnpdParams) => SshnpdParams.fromArgs([]),
        const (SrvdParams) => SrvdParams.fromArgs([]),
        _ => throw ArgumentError("Unsupported parameter type: $T"),
      }
      as T;
}

void writeToConfig() {}
