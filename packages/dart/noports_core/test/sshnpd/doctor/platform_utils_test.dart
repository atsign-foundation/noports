import 'dart:io';

import 'package:noports_core/src/sshnpd/doctor/utils/daemon_processes.dart';
import 'package:noports_core/src/sshnpd/doctor/utils/platform_utils.dart';
import 'package:test/test.dart';

PlatformUtils linuxListing(ListedProcess process) =>
    LinuxUtils(listProcesses: () async => [process]);

PlatformUtils macOSListing(ListedProcess process) =>
    MacOSUtils(listProcesses: () async => [process]);

PlatformUtils windowsListing(ListedProcess process) =>
    WindowsUtils(listProcesses: () async => [process]);

void main() {
  group(
    "Given a process listing whose only sshnpd process is the doctor's own",
    () {
      test(
        'when each platform checks whether sshnpd is running, then it is not',
        () async {
          for (final (listing, daemon) in [
            (linuxListing, ['sshnpd']),
            (macOSListing, ['sshnpd']),
            (windowsListing, [r'C:\NoPorts\sshnpd.exe']),
          ]) {
            final other = listing(ListedProcess(pid + 1, daemon));
            expect(
              await other.isDaemonRunning('sshnpd'),
              isTrue,
              reason: '${other.name} counts the same process under another pid',
            );
            final own = listing(ListedProcess(pid, daemon));
            expect(
              await own.isDaemonRunning('sshnpd'),
              isFalse,
              reason: '${own.name} does not count its own process',
            );
          }
        },
      );
    },
  );

  group('Given a process listing showing SSHNPD.EXE', () {
    test(
      'when each platform checks whether sshnpd is running, then only Windows counts it',
      () async {
        final process = ListedProcess(pid + 1, [r'C:\NoPorts\SSHNPD.EXE']);
        for (final (listing, counted) in [
          (linuxListing, false),
          (macOSListing, false),
          (windowsListing, true),
        ]) {
          final platform = listing(process);
          expect(
            await platform.isDaemonRunning('sshnpd'),
            counted,
            reason:
                '${platform.name} ${counted ? 'counts' : 'does not count'}'
                ' SSHNPD.EXE as sshnpd',
          );
        }
      },
    );
  });

  group('Given a process listing showing SSHNPD', () {
    test(
      'when each platform checks whether sshnpd is running, then only Windows counts it',
      () async {
        final process = ListedProcess(pid + 1, ['/opt/noports/SSHNPD']);
        for (final (listing, counted) in [
          (linuxListing, false),
          (macOSListing, false),
          (windowsListing, true),
        ]) {
          final platform = listing(process);
          expect(
            await platform.isDaemonRunning('sshnpd'),
            counted,
            reason:
                '${platform.name} ${counted ? 'counts' : 'does not count'}'
                ' SSHNPD as sshnpd',
          );
        }
      },
    );
  });
}
