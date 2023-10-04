import 'dart:async';
import 'dart:io';
import 'package:noports_core/src/common/utils.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/sshnp/sshnp.dart';
import 'package:noports_core/src/sshnp/sshnp_impl/sshnp_reverse_mixin.dart';

Completer<T> wrapInCompleter<T>(Future<T> future) {
  final completer = Completer<T>();
  unawaited(
    future.then(completer.complete).catchError(completer.completeError),
  );
  return completer;
}

Future<void> cleanUpAfterReverseSsh(SSHNP sshnp) async {
  if (!wrapInCompleter(sshnp.initialized).isCompleted ||
      sshnp is! SSHNPReverseMixin) {
    // nothing to clean up
    return;
  }

  String homeDirectory = await getHomeDirectory();
  var sshHomeDirectory = getDefaultSshDirectory(homeDirectory);
  sshnp.logger.info('Tidying up files');
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
  await deleteFile('$sshHomeDirectory/${sshnp.sessionId}_sshnp', sshnp.logger);
  await deleteFile(
      '$sshHomeDirectory/${sshnp.sessionId}_sshnp.pub', sshnp.logger);
  await removeEphemeralKeyFromAuthorizedKeys(sshnp.sessionId, sshnp.logger,
      sshHomeDirectory: sshHomeDirectory);
}

Future<bool> deleteFile(String fileName, AtSignLogger logger) async {
  try {
    final file = File(fileName);

    await file.delete();
    return true;
  } catch (e) {
    logger.severe("Error deleting file : $fileName");
    return false;
  }
}

/// Figures out whether we are requesting a direct ssh or not, based on
/// 1) are we talking to a legacy daemon or not?
/// 2) is the host parameter supplied as an atSign or not?
///
/// - If [legacyDaemon] is true
/// -   return false (not supported by legacy daemon)
/// - Else
/// -   if host starts with '@'
/// -     return true (current daemon, and client using rvd)
/// -   else
/// -     return false (current daemon, but client not using rvd)
bool useDirectSsh(bool legacyDaemon, String host) {
  if (legacyDaemon) {
    // legacy daemons only handle reverse ssh
    return false;
  } else {
    // Not a legacy daemon, so can handle direct or reverse ssh
    if (host.startsWith('@')) {
      // If we're using the rvd, with a non-legacy daemon, then
      // we will always go direct
      return true;
    } else {
      // Not using the rvd, so we are going to request that the daemon
      // start a reverse ssh to this client side
      return false;
    }
  }
}
