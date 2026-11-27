import 'package:sshnoports/src/commands/npt.dart' as npt;

/// Runs npt's command on its own, outside atsc, so that a test can compare
/// what atsc npt does with it.
Future<void> main(List<String> args) => npt.main(args);
