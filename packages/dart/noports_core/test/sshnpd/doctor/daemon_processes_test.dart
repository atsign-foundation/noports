import 'dart:convert';
import 'dart:io';

import 'package:noports_core/src/sshnpd/doctor/utils/daemon_processes.dart';
import 'package:test/test.dart';

const doctorPid = 4242;

typedef Proc = (int pid, List<String> args);

const Proc unixDoctor = (doctorPid, ['/usr/bin/sshnpd', '--doctor']);

const Map<String, Object?> windowsDoctor = {
  'ProcessId': doctorPid,
  'Name': 'sshnpd.exe',
  'CommandLine': r'"C:\Program Files\NoPorts\sshnpd.exe" --doctor',
};

Future<List<ListedProcess>> listAsLinux(List<Proc> processes) async {
  final proc = await Directory.systemTemp.createTemp('proc');
  addTearDown(() => proc.delete(recursive: true));
  for (final (pid, args) in processes) {
    final dir = await Directory('${proc.path}/$pid').create();
    await File('${dir.path}/cmdline').writeAsBytes([
      for (final arg in args) ...[...utf8.encode(arg), 0],
    ]);
  }
  return listProcDirectory(proc);
}

List<ListedProcess> listAsMacOS(List<Proc> processes) => parsePsListing(
  [
    for (final (pid, args) in processes) '${'$pid'.padLeft(5)} ${args.first}',
  ].join('\n'),
  [
    for (final (pid, args) in processes)
      '${'$pid'.padLeft(5)} ${args.join(' ')}',
  ].join('\n'),
);

Future<bool> unixReportsDaemon(List<Proc> processes) async {
  final linux = isDaemonListed(
    await listAsLinux(processes),
    'sshnpd',
    selfPid: doctorPid,
    windows: false,
  );
  final macOS = isDaemonListed(
    listAsMacOS(processes),
    'sshnpd',
    selfPid: doctorPid,
    windows: false,
  );
  expect(macOS, linux, reason: 'the Linux and macOS listings agree');
  return linux;
}

bool windowsReportsDaemon(List<Map<String, Object?>> processes) =>
    isDaemonListed(
      parseWin32ProcessListing(jsonEncode(processes)),
      'sshnpd',
      selfPid: doctorPid,
      windows: true,
    );

Map<String, Object?> windowsProcess(int pid, String name, String? line) => {
  'ProcessId': pid,
  'Name': name,
  'CommandLine': line,
};

void main() {
  group('Given the doctor is the only sshnpd process', () {
    test('when the process check runs on Linux or macOS, '
        'then it reports no daemon running', () async {
      expect(
        await unixReportsDaemon([
          unixDoctor,
          (1, ['/sbin/init']),
        ]),
        isFalse,
        reason: "the doctor's own process is not the daemon",
      );
    });

    test('when the process check runs on Windows, '
        'then it reports no daemon running', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(4, 'System', null),
        ]),
        isFalse,
        reason: "the doctor's own process is not the daemon",
      );
    });
  });

  group('Given another process runs the doctor', () {
    test('when the process check runs on Linux or macOS, '
        'then that doctor run is not counted as the daemon', () async {
      expect(
        await unixReportsDaemon([
          unixDoctor,
          (5151, ['/usr/local/bin/sshnpd', '--doctor']),
          (5152, ['/usr/bin/atsc', 'sshnpd', '-o', 'report.txt', '--doctor']),
        ]),
        isFalse,
        reason: 'a --doctor run is not the daemon, whatever its pid',
      );
    });

    test('when the process check runs on Windows, '
        'then that doctor run is not counted as the daemon', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(5151, 'sshnpd.exe', r'C:\NoPorts\sshnpd.exe --doctor'),
          windowsProcess(
            5152,
            'atsc.exe',
            r'"C:\Program Files\NoPorts\atsc.exe" sshnpd --doctor',
          ),
        ]),
        isFalse,
        reason: 'a --doctor run is not the daemon, whatever its pid',
      );
    });
  });

  group('Given this process itself runs sshnpd without --doctor', () {
    test(
      'when the process check runs, then this process is not counted',
      () async {
        expect(
          await unixReportsDaemon([
            (doctorPid, ['/usr/bin/sshnpd', '-a', '@device', '-m', '@mgr']),
          ]),
          isFalse,
          reason: 'the process running the check is never counted',
        );
      },
    );
  });

  group(
    'Given a command line that mentions sshnpd but runs another program',
    () {
      test('when the process check runs on Linux or macOS, '
          'then it reports no daemon running', () async {
        expect(
          await unixReportsDaemon([
            unixDoctor,
            (6001, ['vim', '/home/u/.config/sshnpd/sshnpd.yaml']),
            (6002, ['journalctl', '-u', 'sshnpd', '-f']),
            (6003, ['tail', '-f', '/var/log/sshnpd']),
            (6004, ['/bin/bash', '/home/u/.local/bin/sshnpd.sh']),
            (6005, ['/usr/bin/atsc', 'npt', '-t', '@device', '-d', 'sshnpd']),
            (6006, ['/usr/bin/sshnpd-helper', '-a', '@device']),
            (6007, ['dart', 'run', 'bin/sshnpd.dart', '-a', '@device']),
            (6008, ['dart', 'run', 'bin/atsc.dart', 'sshnpd', '-a', '@d']),
          ]),
          isFalse,
          reason: 'only the program position names the daemon',
        );
      });

      test('when the process check runs on Windows, '
          'then it reports no daemon running', () {
        expect(
          windowsReportsDaemon([
            windowsDoctor,
            windowsProcess(
              6001,
              'notepad.exe',
              r'notepad.exe C:\ProgramData\NoPorts\sshnpd.yaml',
            ),
            windowsProcess(
              6002,
              'powershell.exe',
              "powershell -NoProfile -Command Get-WinEvent -FilterHashtable "
                  "@{LogName='Application'; ProviderName='sshnpd'}",
            ),
            windowsProcess(
              6003,
              'sshnpdService.exe',
              r'"C:\Program Files\NoPorts\sshnpdService.exe"',
            ),
          ]),
          isFalse,
          reason: 'only the program position names the daemon',
        );
      });
    },
  );

  group('Given the daemon runs as sshnpd', () {
    test('when the process check runs on Linux or macOS, '
        'then it reports the daemon running', () async {
      for (final Proc daemon in [
        (1406, ['/usr/bin/sshnpd', '-a', '@device', '-m', '@mgr', '-v']),
        (1407, ['sshnpd', '-a', '@device', '--po', '127.0.0.1:22']),
        (1408, ['./sshnpd', '-a', '@device', '-m', '@mgr']),
      ]) {
        expect(
          await unixReportsDaemon([unixDoctor, daemon]),
          isTrue,
          reason: 'sshnpd in the program position is the daemon: $daemon',
        );
      }
    });

    test('when the process check runs on Windows, '
        'then it reports the daemon running', () {
      for (final daemon in [
        windowsProcess(
          3001,
          'sshnpd.exe',
          r'"C:\Program Files\NoPorts\sshnpd.exe" -a @device -m @mgr -d dev',
        ),
        windowsProcess(3002, 'SSHNPD.EXE', r'C:\NoPorts\SSHNPD.EXE -a @device'),
        windowsProcess(3003, 'sshnpd.exe', 'sshnpd -a @device -m @mgr'),
      ]) {
        expect(
          windowsReportsDaemon([windowsDoctor, daemon]),
          isTrue,
          reason: 'sshnpd.exe in the program position is the daemon: $daemon',
        );
      }
    });
  });

  group('Given the daemon runs as atsc sshnpd', () {
    test('when the process check runs on Linux or macOS, '
        'then it reports the daemon running', () async {
      expect(
        await unixReportsDaemon([
          unixDoctor,
          (1501, ['/usr/bin/atsc', 'sshnpd', '-a', '@device', '-m', '@mgr']),
        ]),
        isTrue,
        reason: 'atsc with the sshnpd subcommand is the daemon',
      );
    });

    test('when the process check runs on Windows, '
        'then it reports the daemon running', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(
            1501,
            'atsc.exe',
            r'"C:\Program Files\NoPorts\atsc.exe" sshnpd -a @device -m @mgr',
          ),
        ]),
        isTrue,
        reason: 'atsc.exe with the sshnpd subcommand is the daemon',
      );
    });
  });

  group('Given the daemon is installed under a path with a space', () {
    test('when the process check runs on Linux or macOS, '
        'then it reports the daemon running', () async {
      for (final Proc daemon in [
        (1406, ['/opt/No Ports/sshnpd', '-a', '@device']),
        (1407, ['/opt/No Ports/atsc', 'sshnpd', '-a', '@device']),
      ]) {
        expect(
          await unixReportsDaemon([unixDoctor, daemon]),
          isTrue,
          reason: 'a space in the program path does not split it: $daemon',
        );
      }
    });
  });

  group('Given a Linux /proc directory', () {
    test('when it is listed, then each process keeps its exact arguments '
        'and an entry without a readable cmdline is left out', () async {
      final proc = await Directory.systemTemp.createTemp('proc');
      addTearDown(() => proc.delete(recursive: true));
      Future<void> cmdline(String entry, List<int> bytes) async {
        final dir = await Directory('${proc.path}/$entry').create();
        await File('${dir.path}/cmdline').writeAsBytes(bytes);
      }

      await cmdline('1406', [
        ...utf8.encode('/opt/No Ports/sshnpd'),
        0,
        ...utf8.encode('-d'),
        0,
        ...utf8.encode('my device'),
        0,
      ]);
      await cmdline('2', []);
      await Directory('${proc.path}/3').create();
      await cmdline('self', [...utf8.encode('/usr/bin/sshnpd'), 0]);
      await File('${proc.path}/uptime').writeAsString('1.0 2.0');

      final processes = await listProcDirectory(proc);
      expect(
        {for (final p in processes) p.pid: p.args},
        {
          1406: ['/opt/No Ports/sshnpd', '-d', 'my device'],
          2: <String>[],
        },
      );
    });
  });

  group('Given macOS ps listings', () {
    test("when a process's args begin with its command name, "
        'then the rest of its args are its arguments', () {
      final processes = parsePsListing(
        ' 1406 /opt/No Ports/sshnpd\n',
        ' 1406 /opt/No Ports/sshnpd -a @device -m @mgr\n',
      );
      expect(processes.single.args, [
        '/opt/No Ports/sshnpd',
        '-a',
        '@device',
        '-m',
        '@mgr',
      ]);
    });

    test("when a process's args do not begin with its command name, "
        'then it is listed by its command name alone', () {
      final processes = parsePsListing(' 1406 sshnpd\n', ' 1406 (sshnpd)\n');
      expect(processes.single.args, ['sshnpd']);
    });

    test('when a process is in only one listing, then it is left out', () {
      final processes = parsePsListing(
        ' 1406 sshnpd\n 1407 sshnpd\n',
        ' 1407 sshnpd -a @device\n 1408 sshnpd -a @device\n',
      );
      expect(processes.map((p) => p.pid), [1407]);
    });
  });

  group("Given a Windows command line whose first token is not the image's "
      'path', () {
    test('when the image path has an unquoted space, '
        'then the daemon is still counted', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(
            3201,
            'sshnpd.exe',
            r'C:\Program Files\NoPorts\sshnpd.exe -a @device',
          ),
        ]),
        isTrue,
        reason: 'the image name, not the first token, names the program',
      );
    });

    test('when the image path has an unquoted space and --doctor follows, '
        'then that doctor run is not counted', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(
            3202,
            'sshnpd.exe',
            r'C:\Program Files\NoPorts\sshnpd.exe --doctor',
          ),
        ]),
        isFalse,
        reason: 'arguments after the first token still carry --doctor',
      );
    });

    test('when the first token differs from the image, '
        'then the image decides the program', () {
      for (final (daemon, counted) in [
        (windowsProcess(3203, 'atsc.exe', 'launcher sshnpd -a @device'), true),
        (windowsProcess(3204, 'sshnpd.exe', 'renamed -a @device'), true),
        (
          windowsProcess(3205, 'notepad.exe', r'"C:\NoPorts\sshnpd.exe" -a @d'),
          false,
        ),
      ]) {
        expect(
          windowsReportsDaemon([windowsDoctor, daemon]),
          counted,
          reason: 'the image name is the program: $daemon',
        );
      }
    });
  });

  group('Given Windows cannot read a process command line', () {
    test('when its image is sshnpd.exe, then it is counted as the daemon', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(3101, 'sshnpd.exe', null),
        ]),
        isTrue,
        reason: 'the image name stands in for an unreadable command line',
      );
    });

    test('when its image is atsc.exe, '
        'then it is not counted, since its subcommand is unknown', () {
      expect(
        windowsReportsDaemon([
          windowsDoctor,
          windowsProcess(3102, 'atsc.exe', null),
        ]),
        isFalse,
        reason: 'atsc alone does not say which program it runs',
      );
    });
  });

  group('Given a Win32_Process JSON listing', () {
    test('when it is parsed, then each process keeps its pid and arguments', () {
      const output =
          '[{"ProcessId":0,"Name":"System Idle Process",'
          r'"CommandLine":null},{"ProcessId":3001,"Name":"sshnpd.exe",'
          r'"CommandLine":"\"C:\\Program Files\\NoPorts\\sshnpd.exe\" -a @device'
          r' -d \u0027dev\u0027"}]';
      final processes = parseWin32ProcessListing(output);
      expect(processes.map((p) => p.pid), [0, 3001]);
      expect(processes.first.args, ['System Idle Process']);
      expect(processes.last.args, [
        'sshnpd.exe',
        '-a',
        '@device',
        '-d',
        "'dev'",
      ]);
    });

    test('when it is a single object, then that process is listed', () {
      final processes = parseWin32ProcessListing(
        jsonEncode(
          windowsProcess(
            3001,
            'sshnpd.exe',
            r'C:\NoPorts\sshnpd.exe -a @device',
          ),
        ),
      );
      expect(processes.single.pid, 3001);
    });

    test('when it is not JSON, then no process is listed', () {
      for (final output in ['', 'Get-CimInstance : Access denied']) {
        expect(parseWin32ProcessListing(output), isEmpty, reason: output);
      }
    });
  });

  group('Given the platform listing commands', () {
    test(
      'when they are read, then they are the commands the parsers expect',
      () {
        expect(linuxProcDirectory, '/proc');
        expect(macOSCommandNameListing, ['ps', '-A', '-o', 'pid=,comm=']);
        expect(macOSArgumentsListing, ['ps', '-A', '-o', 'pid=,args=']);
        expect(windowsProcessListing, [
          'powershell',
          '-NoProfile',
          '-NonInteractive',
          '-Command',
          'ConvertTo-Json -Compress -InputObject @(Get-CimInstance -ClassName'
              ' Win32_Process | Select-Object ProcessId, Name, CommandLine)',
        ]);
      },
    );
  });
}
