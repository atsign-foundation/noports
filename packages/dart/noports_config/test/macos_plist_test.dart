import 'package:flutter_test/flutter_test.dart';
import 'package:noports_config/platform/macos_service_manager.dart';

void main() {
  const legacy = '''
<plist version="1.0"><dict>
	<key>Label</key><string>com.atsign.sshnpd</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Users/me/.local/bin/sshnpd</string>
		<string>-a</string>
		<string>@ssh_1</string>
		<string>--po</string>
		<string>*:*</string>
	</array>
	<key>KeepAlive</key><true/>
</dict></plist>''';

  test('parses legacy program arguments and flags them as unmanaged', () {
    final args = MacosServiceManager.parseProgramArguments(legacy);
    expect(args, ['/Users/me/.local/bin/sshnpd', '-a', '@ssh_1', '--po', '*:*']);
    expect(MacosServiceManager.isManagedDefinition(args, '/x/sshnpd.yaml'), isFalse);
  });

  test('built plist round-trips and is recognised as managed', () {
    final plist = MacosServiceManager.buildPlist(
      label: 'com.atsign.sshnpd',
      programArguments: ['/Users/me/.local/bin/sshnpd', '--config', '/Users/me/Library/Application Support/NoPorts/sshnpd.yaml'],
      logPath: '/Users/me/.sshnpd/logs/sshnpd.log',
    );
    final args = MacosServiceManager.parseProgramArguments(plist);
    expect(args.length, 3);
    expect(MacosServiceManager.isManagedDefinition(args, '/Users/me/Library/Application Support/NoPorts/sshnpd.yaml'), isTrue);
    expect(plist, contains('<key>StandardOutPath</key>'));
    expect(plist, contains('<key>RunAtLoad</key>'));
  });

  test('rotation agent plist carries a copy-truncate script', () {
    final plist = MacosServiceManager.buildRotatePlist(
      label: 'com.atsign.sshnpd.logrotate',
      logPath: "/Users/o'brien/.sshnpd/logs/sshnpd.log",
      maxBytes: 5242880,
      intervalSeconds: 21600,
    );
    final args = MacosServiceManager.parseProgramArguments(plist);
    expect(args.length, 3);
    expect(args[0], '/bin/sh');
    expect(args[2], contains('stat -f %z'));
    expect(args[2], contains('-gt 5242880'));
    expect(args[2], contains(': > "\$f"'));
    // The awkward quote in the path survives shell quoting.
    expect(args[2], contains("o'\\''brien"));
    expect(plist, contains('<integer>21600</integer>'));
  });
}
