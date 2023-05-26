import 'dart:io';

import 'package:args/args.dart';
import 'package:io/ansi.dart';
import 'package:sshnoports/home_directory.dart';
import 'package:sshnoports/process_util.dart';
import 'package:sshnoports/version.dart';

/// This binary is not meant to be ran here.
/// It is meant to be ran in the same directory as the other binaries: `sshnp`, `sshnpd`, `sshrvd`, `sshrv`, `.startup.sh`, etc.
/// The arguments are the same as `sshnpd` as it will initialize a `.startup.sh` script with the given arguments for starting the daemon.

/// This binary will:
/// 1. make [~/.ssh/, ~/sshnp/, ~/.atsign/keys, /run/sshd] directories if they don't exist
/// 2. copy over all files to ~/sshnp directory, ask to overwrite if already exists
/// 3. write custom healthcheck.sh and write it to `~/sshnp`
/// 4. write custom .startup.sh and write it to `~`
/// 5. do one final pass check if files and directories exist

/// If there are any new binaries added, add them to the `filesToCopyOverToSshnpDir` list.
const List<String> filesToCopyOverToSshnpDir = [
  'activate_cli',
  'sshnp',
  'sshnpd',
  'sshrv',
  'sshrvd',
  'sshrvd.sh',
  'sshnpd.sh',
  'tmux-sshrvd.sh',
  'tmux-sshnpd.sh',
  'install_sshnpd'
];

const String runSshdDir = '/run/sshd'; // /run/sshd

late String? homeDir; // ~

final String sshHomeDir = '$homeDir/.ssh'; // ~/.ssh
final String atSignKeysDir = '$homeDir/.atsign/keys'; // ~/.atsign/keys
final String sshnpHomeDir = '$homeDir/sshnp'; // ~/sshnp/bin

final List<String> directoriesToCreate = [
  runSshdDir,
  sshHomeDir,
  atSignKeysDir,
  sshnpHomeDir,
];

// Usage: "./install_sshnpd -a @66dear32 -m @jeremy_0 -d jeremydevice -s -u -v"
// cd /app/repo/bin ; ./install_sshnpd -a @66dear32 -m @jeremy_0 -d jeremydevice -s -u -v ; cd ~ ; sh .startup.sh
void main(List<String> arguments) async {
  try {
    await _main(arguments);
  } catch (error, stackTrace) {
    stderr.writeln('sshnpd: ${error.toString()}');
    stderr.writeln('stack trace: ${stackTrace.toString()}');
    await stderr.flush().timeout(Duration(milliseconds: 100));
    exit(1);
  }
}

Future<void> _main(List<String> arguments) async {
  stdout.writeln('Starting install...');
  final ArgParser parser = ArgParser();
  parser.addOption('keyFile', abbr: 'k', mandatory: false, help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/');
  parser.addOption('atsign', abbr: 'a', mandatory: true, help: 'atSign of this device');
  parser.addOption('manager',
      abbr: 'm', mandatory: true, help: 'Managers atSign, that this device will accept triggers from');
  parser.addOption('device',
      abbr: 'd',
      mandatory: false,
      defaultsTo: "default",
      help: 'Send a trigger to this device, allows multiple devices share an atSign');
  parser.addFlag('sshpublickey', abbr: 's', help: 'Update authorized_keys to include public key from sshnp');
  parser.addFlag('username',
      abbr: 'u', help: 'Send username to the manager to allow sshnp to display username in command line');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  try {
    homeDir = getHomeDirectory();
    if (homeDir == null) {
      throw Exception('Could not get home directory...');
    }

    final ArgResults argResults = parser.parse(arguments);
    ProcessResult pres;
    String cmd;

    // 1. make ~/.ssh/, ~/sshnp/, ~/.atsign/keys, /run/sshd directories if they don't exist
    cmd = 'mkdir -p $sshHomeDir $sshnpHomeDir $atSignKeysDir $runSshdDir';
    pres = await runCommand(cmd);
    stdout.writeln('[${lightGreen.wrap('\u2713')}] Ran $cmd | pres.exitcode: ${pres.exitCode}');

    // 2. copy over all files to ~/sshnp directory
    // 2a. check if one of the files exist in ~/sshnp, overwrite? exit if no.
    for (final String file in filesToCopyOverToSshnpDir) {
      if (File('$sshnpHomeDir/$file').existsSync()) {
        stdout.writeln(
            '[${lightRed.wrap('\u2717')}] Sshnp was already installed. Do you want to overwrite it? (y/n)');
        final String? response = stdin.readLineSync();
        if (response == null || response.toLowerCase() != 'y') {
          stdout.writeln('[${lightRed.wrap('\u2717')}] Aborting installation...');
          exit(1);
        }
      }
    }

    // 2b. copy over all files to ~/sshnp
    for (final String file in filesToCopyOverToSshnpDir) {
      // if file to copy doesn't exist, it's okay
      if (!File(file).existsSync()) {
        continue;
      }
      cmd = 'cp $file $sshnpHomeDir';
      pres = await runCommand(cmd);
    }
    stdout.writeln(
        '[${lightGreen.wrap('\u2713')}] Copied all binaries to $sshnpHomeDir | pres.exitcode: ${pres.exitCode}');

    // 3. write custom .healthcheck.sh and write it to `~/sshnp`
    final String healthCheckShScriptString = '''
#!/bin/bash
# Make directories
mkdir -p ${_generateSpacedOutStrings(directoriesToCreate)}

# touch authorized_keys and chmod if dne
AUTHORIZEDKEYSFILE=$homeDir/.ssh/authorized_keys
if [ ! -f \$AUTHORIZEDKEYSFILE ]; then
    touch \$AUTHORIZEDKEYSFILE
    chmod 600 \$AUTHORIZEDKEYSFILE
    if [ ! -f \$AUTHORIZEDKEYSFILE ]; then
        echo "$homeDir/.ssh/authorized_keys does not exist"
        exit 1
    fi
fi

# exit if atKeys dne
ATKEYS=$homeDir/.atsign/keys/${argResults['atsign']}_key.atKeys
if [ ! -f \$ATKEYS ]; then
    echo "$homeDir/.atsign/keys/${argResults['atsign']}_key.atKeys does not exist"
    exit 1
fi

# exit if /usr/sbin/sshd dne
SSHD=/usr/sbin/sshd
if [ ! -f \$SSHD ]; then
    echo "\$SSHD does not exist. sshd is required to run sshnpd"
    exit 1
fi

# exit if $sshnpHomeDir/sshnpd dne
SSHNPD=$sshnpHomeDir/sshnpd
if [ ! -f \$SSHNPD ]; then
    echo "\$SSHNPD does not exist"
    exit 1
fi

echo "Health check passed"
''';
    final File healthCheckShScript = File('$sshnpHomeDir/healthcheck.sh');
    await healthCheckShScript.writeAsString(healthCheckShScriptString);

    // 4. write custom .startup.sh and write it to `~`
    final String startupShScriptString = '''
#!/bin/bash
# run $sshnpHomeDir/healthcheck.sh
sh $sshnpHomeDir/healthcheck.sh

ssh-keygen -A
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
while true
do
$sshnpHomeDir/sshnpd -a ${argResults['atsign']} -m ${argResults['manager']} ${argResults['device'] != null ? '-d ${argResults['device']}' : ''} ${argResults['sshpublickey'] ? '-s' : ''} ${argResults['username'] ? '-u' : ''} ${argResults['verbose'] ? '-v' : ''}${argResults['keyFile'] != null ? '-k ${argResults['keyFile']}' : ''}
sleep 3
done
''';
    final File startupShScript = File('$sshnpHomeDir/.startup.sh');
    await startupShScript.writeAsString(startupShScriptString);
    stdout.writeln('[${lightGreen.wrap('\u2713')}] Wrote ${startupShScript.uri.toFilePath()} | pres.exitcode: ${pres.exitCode}');

    // copy it over to ~
    cmd = 'cp $sshnpHomeDir/.startup.sh $homeDir';
    pres = await runCommand(cmd);
    stdout.writeln('[${lightGreen.wrap('\u2713')}] Copied .startup.sh to $homeDir | pres.exitcode: ${pres.exitCode}');

    // 5a. check that following dirs exist: /run/sshd ~/sshnp ~/.ssh ~/.atsign/keys
    final List<String> dirsToCheck = [
      runSshdDir,
      sshnpHomeDir,
      sshHomeDir,
      atSignKeysDir,
    ];
    for (final String dir in dirsToCheck) {
      if (!Directory(dir).existsSync()) {
        // try making it again
        cmd = 'mkdir -p $dir';
        pres = await runCommand(cmd);
        if (pres.exitCode != 0) {
          throw Exception('Directory $dir does not exist but should');
        }
      } else {
        stdout.writeln('${_getCheckmark()} Directory $dir exists');
      }
    }

    // 5b. check that following files exist: ~/.startup.sh and all binaries in ~/sshnp
    final List<String> filesToCheck = [
      '$homeDir/.startup.sh',
      '$sshnpHomeDir/sshnpd',
      // '$sshnpHomeDir/sshnp',
      // '$sshnpHomeDir/sshrv',
      // '$sshnpHomeDir/sshrvd',
    ];
    for (final String file in filesToCheck) {
      if (!File(file).existsSync()) {
        throw Exception('File $file does not exist but should');
      } else {
        stdout.writeln('${_getCheckmark()} File $file exists');
      }
    }

    stdout.writeln('${_getCheckmark()} ${lightCyan.wrap('Finished installation!')}');
  } catch (e) {
    stderr.writeln(e);
    _printUsage(parser);
  }
}

void _printUsage(ArgParser parser) {
  version();
  stdout.writeln(parser.usage);
}

String _getCheckmark() {
  return '[${lightGreen.wrap('\u2713')}]';
}

/// give it something like ['foo', 'bar'] will give you 'foo bar'
String _generateSpacedOutStrings(List<String> strings) {
  String result = '';
  for (final String string in strings) {
    result += '$string ';
  }
  return result.trim();
}