// dart packages
import 'dart:io';
// local packages
import 'package:sshnoports/home_directory.dart';




Future<void> cleanUp(sessionId,_logger) async {
  String? homeDirectory = getHomeDirectory();
  if (homeDirectory == null) {
    return;
  }
  var sshHomeDirectory = homeDirectory + "/.ssh/";
  if (Platform.isWindows) {
    sshHomeDirectory = homeDirectory + '\\.ssh\\';
  }
// Wait a few seconds for the remote ssh session to connect back here
// do we need to wait ?
 _logger.info('Tidying up files');
  sleep(Duration(seconds: 2));
  await Process.run('rm', ['${sessionId}_rsa', '${sessionId}_rsa.pub'], workingDirectory: sshHomeDirectory);
  await Process.run('sed', ['-i', '/$sessionId/d', 'authorized_keys'], workingDirectory: sshHomeDirectory);
}