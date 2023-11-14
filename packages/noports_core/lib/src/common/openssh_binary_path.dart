import 'dart:io';

const String _windowsOpensshPath = r'C:\Windows\System32\OpenSSH\ssh.exe';
const String _unixOpensshPath = '/usr/bin/ssh';

String get opensshBinaryPath =>
    Platform.isWindows ? _windowsOpensshPath : _unixOpensshPath;
