import 'dart:io';

import 'package:args/args.dart';
import 'package:sshnoports/home_directory.dart';
import 'package:sshnoports/process_util.dart';
import 'package:sshnoports/version.dart';

/// This binary is not meant to be ran here.
/// It is meant to be ran in the same directory as the other binaries: `sshnp`, `sshnpd`, `sshrvd`, `sshrv`, `.startup.sh`, etc.
/// The arguments are the same as `sshnpd` as it will initialize a `.startup.sh` script with the arguments for starting the daemon.

/// The files (in the current directory that this binary is being ran in) will copy the following files (usually comes along with this binary from untarred .tgz) into `~/sshnp`
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

const String usrLocalAtDir = '/usr/local/at';       // /usr/local/at
const String runSshdDir = '/run/sshd';              // /run/sshd

late String? homeDir;  // ~

final String sshHomeDir = '$homeDir/.ssh';                  // ~/.ssh
final String atSignKeysDir = '$homeDir/.atsign/keys';       // ~/.atsign/keys
final String sshnpHomeBinDir = '$homeDir/.atsign/keys';    // ~/.sshnp/bin

// Usage: "./install_sshnpd --help"
// ./install_sshnpd -a @66dear32 -m @lemon -d lemon -s -u -v
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
  print('Starting...');
  final ArgParser parser = ArgParser();
  parser.addOption('keyFile', abbr: 'k', mandatory: false, help: 'Sending atSign\'s keyFile if not in ~/.atsign/keys/');
  parser.addOption('atsign', abbr: 'a', mandatory: true, help: 'atSign of this device');
  parser.addOption('manager',
      abbr: 'm', mandatory: true, help: 'Managers atSign, that this device will accept triggers from');
  parser.addOption('device', abbr: 'd', mandatory: false, defaultsTo: "default", help: 'Send a trigger to this device, allows multiple devices share an atSign');
  parser.addFlag('sshpublickey', abbr: 's', help: 'Update authorized_keys to include public key from sshnp');
  parser.addFlag('username',
      abbr: 'u', help: 'Send username to the manager to allow sshnp to display username in command line');
  parser.addFlag('verbose', abbr: 'v', help: 'More logging');

  try {
    homeDir = getHomeDirectory();
    if (homeDir == null) {
      throw Exception('Could not get home directory');
    }


    final ArgResults argResults = parser.parse(arguments);
    ProcessResult pres;
    // 1. make ~/.ssh/, ~/sshnp/bin, ~/.atsign/keys, /usr/local/at directories if they don't exist
    pres = await runCommand('mkdir -p $homeDir/.ssh $homeDir/.sshnp/bin $homeDir/.atsign/keys /usr/local/at /run/sshd');
    stdout.writeln('done mkdir -p $homeDir/.ssh $homeDir/.sshnp $homeDir/.atsign/keys /usr/local/at /run/sshd| pres.exitcode: ${pres.exitCode}');

    // 2. copy over files to ~/.sshnp/bin directory
    for (final String file in filesToCopyOverToSshnpDir) {
      // if file doesn't exist, it's okay
      if (!File(file).existsSync()) {
        continue;
      }

      pres = await runCommand('cp $file $homeDir/.sshnp/bin');
    }
    stdout.writeln('done cp files $homeDir/.sshnp/bin | pres.exitcode: ${pres.exitCode}');

    // 3. copy sshnpd to /usr/local/at
    pres = await runCommand('cp $homeDir/.sshnp/bin/sshnpd /usr/local/at');
    stdout.writeln('cp $homeDir/.sshnp/bin/sshnpd /usr/local/at | pres.exitcode: ${pres.exitCode}');

    // 4. write custom .startup.sh and write it to `~`
    final String startupShScriptString = 
'''
#!/bin/bash
ssh-keygen -A
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
while true
do
/usr/local/at/sshnpd -a ${argResults['atsign']} -m ${argResults['manager']} ${argResults['device'] != null ? '-d ${argResults['device']}' : ''} ${argResults['sshpublickey'] ? '-s' : ''} ${argResults['username'] ? '-u' : ''} ${argResults['verbose'] ? '-v' : ''}${argResults['keyFile'] != null ? '-k ${argResults['keyFile']}' : ''}
sleep 3
done
''';
    final File startupShScript = File('$homeDir/.startup.sh');
    await startupShScript.writeAsString(startupShScriptString);
    // write startupShScript in ~
    // pres = await runCommand('cp .startup.sh ~/.startup.sh');
    // stdout.writeln('cp .startup.sh ~/.startup.sh | pres.exitcode: ${pres.exitCode}');
    stdout.writeln('$homeDir/.startup.sh exists?: ${startupShScript.existsSync()}');

    // also chmod 755 ~/.startup.sh
    pres = await runCommand('chmod 755 $homeDir/.startup.sh');
    stdout.writeln('chmod 755 $homeDir/.startup.sh | pres.exitcode: ${pres.exitCode}');
    stdout.writeln('cat $homeDir/.startup.sh: \n---\n${(await runCommand('cat $homeDir/.startup.sh')).stdout}\n---\n');

    // 5. `touch ~/.ssh/authorized_keys` and `chmod 600 ~/.ssh/authorized_keys`
    pres = await runCommand('touch $homeDir/.ssh/authorized_keys');
    stdout.writeln('touch $homeDir/.ssh/authorized_keys, pres.exitcode: ${pres.exitCode}');

    pres = await runCommand('chmod 600 $homeDir/.ssh/authorized_keys');
    stdout.writeln('chmod 600 $homeDir/.ssh/authorized_keys, pres.exitcode: ${pres.exitCode}');
  } catch (e) {
    stderr.writeln(e);
    printUsage(parser);
  }
}

void printUsage(ArgParser parser) {
  version();
  stdout.writeln(parser.usage);
}
