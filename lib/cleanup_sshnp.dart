// dart packages
import 'dart:io';
// local packages
import 'package:sshnoports/home_directory.dart';
// @platform packages
import 'package:at_utils/at_logger.dart';

Future<void> cleanUp(String sessionId, AtSignLogger _logger) async {
  String? homeDirectory = getHomeDirectory();
  if (homeDirectory == null) {
    return;
  }
  var sshHomeDirectory = homeDirectory + "/.ssh/";
  if (Platform.isWindows) {
    sshHomeDirectory = homeDirectory + '\\.ssh\\';
  }
// Wait a few seconds for the remote ssh session to connect back here
// do we need to wait ? Yes as it takes time for the reverse ssh to connect
// 5 seconds seems like a reasonable time...
// could make it an option if folks have trouble.
  _logger.info('Tidying up files');

  sleep(Duration(seconds: 5));
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
  await deleteFile('$sshHomeDirectory${sessionId}_rsa', _logger);
  await deleteFile('$sshHomeDirectory${sessionId}_rsa.pub', _logger);
  await removeSession(sshHomeDirectory, sessionId, _logger);

}

Future<int> deleteFile(String fileName, AtSignLogger _logger) async {
  try {
    final file = File(fileName);

    await file.delete();
  } catch (e) {
    _logger.severe("Error deleting file : $fileName");
  }
  return 0;
}

Future<void> removeSession(String sshHomeDirectory, String sessionId, AtSignLogger _logger) async {
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
    _logger.severe('Unable to tidy up ${sshHomeDirectory}authorized_keys');
  }
}
