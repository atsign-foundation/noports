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
}
