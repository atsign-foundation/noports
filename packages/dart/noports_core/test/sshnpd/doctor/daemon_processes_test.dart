import 'dart:convert';

import 'package:noports_core/src/sshnpd/doctor/utils/daemon_processes.dart';
import 'package:test/test.dart';

const doctorPid = 4242;

const unixDoctorLine = '$doctorPid /usr/bin/sshnpd --doctor';

const Map<String, Object?> windowsDoctor = {
  'ProcessId': doctorPid,
  'Name': 'sshnpd.exe',
  'CommandLine': r'"C:\Program Files\NoPorts\sshnpd.exe" --doctor',
};

bool unixReportsDaemon(List<String> pgrepLines) => isDaemonListed(
  parsePgrepListing('${pgrepLines.join('\n')}\n'),
  'sshnpd',
  selfPid: doctorPid,
  windows: false,
);

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
        'then it reports no daemon running', () {
      expect(
        unixReportsDaemon([unixDoctorLine, '1 /sbin/init']),
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
        'then that doctor run is not counted as the daemon', () {
      expect(
        unixReportsDaemon([
          unixDoctorLine,
          '5151 /usr/local/bin/sshnpd --doctor',
          '5152 /usr/bin/atsc sshnpd -o report.txt --doctor',
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
    test('when the process check runs, then this process is not counted', () {
      expect(
        unixReportsDaemon(['$doctorPid /usr/bin/sshnpd -a @device -m @mgr']),
        isFalse,
        reason: 'the process running the check is never counted',
      );
    });
  });

  group(
    'Given a command line that mentions sshnpd but runs another program',
    () {
      test('when the process check runs on Linux or macOS, '
          'then it reports no daemon running', () {
        expect(
          unixReportsDaemon([
            unixDoctorLine,
            '6001 vim /home/u/.config/sshnpd/sshnpd.yaml',
            '6002 journalctl -u sshnpd -f',
            '6003 tail -f /var/log/sshnpd',
            '6004 /bin/bash /home/u/.local/bin/sshnpd.sh',
            '6005 /usr/bin/atsc npt -t @device -d sshnpd',
            '6006 /usr/bin/sshnpd-helper -a @device',
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
        'then it reports the daemon running', () {
      for (final daemonLine in [
        '1406 /usr/bin/sshnpd -a @device -m @mgr -d dev -v',
        '1407 sshnpd -a @device -m @mgr --po 127.0.0.1:22 -d dev',
        '1408 ./sshnpd -a @device -m @mgr',
      ]) {
        expect(
          unixReportsDaemon([unixDoctorLine, daemonLine]),
          isTrue,
          reason: 'sshnpd in the program position is the daemon: $daemonLine',
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
        'then it reports the daemon running', () {
      expect(
        unixReportsDaemon([
          unixDoctorLine,
          '1501 /usr/bin/atsc sshnpd -a @device -m @mgr -d dev',
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

  group('Given PowerShell output as Windows PowerShell 5.1 prints it', () {
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
        r'C:\Program Files\NoPorts\sshnpd.exe',
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
}
