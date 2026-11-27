import 'dart:io';

import 'package:sshnoports/src/admin/web_app.dart';

/// Prints the directory np_admin would serve its web app from.
void main() {
  stdout.writeln(webAppDirectory().absolute.path);
}
