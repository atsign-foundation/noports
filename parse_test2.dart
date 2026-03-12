import 'dart:io';

void main() async {
  final result = await Process.run('launchctl', ['list', 'com.atsign.sshnpd']);
  final output = result.stdout.toString();
  final exitMatch = RegExp(r'"LastExitStatus"\s*=\s*(\d+);').firstMatch(output);
  int exitCode = -1;
  if (exitMatch != null) {
    exitCode = int.tryParse(exitMatch.group(1)!) ?? -1;
    if (exitCode > 255) {
        exitCode = exitCode >> 8;
    }
  }
  
  print('Exit code: $exitCode');
  
  final pidMatch = RegExp(r'"PID"\s*=\s*(\d+);').firstMatch(output);
  String activeState = 'unknown';
  if (pidMatch != null) {
     activeState = 'active';
  } else if (exitCode > 0) {
     activeState = 'failed';
  } else {
     activeState = 'inactive';
  }
  print('Active state: $activeState');
}
