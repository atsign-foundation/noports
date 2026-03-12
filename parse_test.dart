import 'dart:io';

void main() async {
  final listResult = await Process.run('launchctl', ['list']);
  final lines = listResult.stdout.toString().split('\n');
  String? actualLabel;
  for (var line in lines) {
    if (line.contains('sshnpd')) {
      final parts = line.trim().split(RegExp(r'\s+'));
      if (parts.length >= 3) {
        actualLabel = parts[2];
        break;
      }
    }
  }

  if (actualLabel == null) return;

  final result = await Process.run('launchctl', ['list', actualLabel]);
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
