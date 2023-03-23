// dart packages
import 'dart:io';
// local packages
import 'package:sshnoports/home_directory.dart';
// atPlatform packages
import 'package:at_utils/at_logger.dart';

Future<void> cleanUp(String sessionId, AtSignLogger logger) async {
  String? homeDirectory = getHomeDirectory();
  if (homeDirectory == null) {
    return;
  }
  var sshHomeDirectory = "$homeDirectory/.ssh/";
  if (Platform.isWindows) {
    sshHomeDirectory = r'$homeDirectory\.ssh\';
  }
  logger.info('Tidying up files');
// Delete the generated RSA keys and remove the entry from ~/.ssh/authorized_keys
  await deleteFile('$sshHomeDirectory${sessionId}_rsa', logger);
  await deleteFile('$sshHomeDirectory${sessionId}_rsa.pub', logger);
  await removeSession(sshHomeDirectory, sessionId, logger);
}

Future<int> deleteFile(String fileName, AtSignLogger logger) async {
  try {
    final file = File(fileName);

    await file.delete();
  } catch (e) {
    logger.severe("Error deleting file : $fileName");
  }
  return 0;
}

Future<void> removeSession(
    String sshHomeDirectory, String sessionId, AtSignLogger logger) async {
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
