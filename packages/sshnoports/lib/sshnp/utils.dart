import 'dart:io';
import 'package:sshnoports/common/utils.dart';
import 'package:at_utils/at_logger.dart';
import 'package:sshnoports/sshnp/sshnp.dart';

Future<void> cleanUpAfterReverseSsh(SSHNP sshnp) async {
  if (!sshnp.initialized) {
    // never got started, nothing to clean up
    return;
  }
  if (sshnp.direct) {
    // did a direct ssh, not a reverse one - nothing to clean up
    return;
  }

  String? homeDirectory = getHomeDirectory();
  if (homeDirectory == null) {
    return;
  }
  var sshHomeDirectory = "$homeDirectory/.ssh/";
  if (Platform.isWindows) {
    sshHomeDirectory = r'$homeDirectory\.ssh\';
  }
  sshnp.logger.info('Tidying up files');
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
  await deleteFile('$sshHomeDirectory${sshnp.sessionId}_sshnp', sshnp.logger);
  await deleteFile('$sshHomeDirectory${sshnp.sessionId}_sshnp.pub', sshnp.logger);
  await removeFromAuthorizedKeys(sshHomeDirectory, sshnp.sessionId, sshnp.logger);
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

Future<void> removeFromAuthorizedKeys(String sshHomeDirectory, String sessionId, AtSignLogger logger) async {
  try {
    final File file = File('${sshHomeDirectory}authorized_keys');
    // read into List of strings
    final List<String> lines = await file.readAsLines();
    // find the line we want to remove
    lines.removeWhere((element) => element.contains(sessionId));
    // Write back the file and add a \n
    await file.writeAsString(lines.join('\n'));
    await file.writeAsString('\n', mode: FileMode.writeOnlyAppend);
  } catch (e) {
    logger.severe('Unable to tidy up ${sshHomeDirectory}authorized_keys');
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
