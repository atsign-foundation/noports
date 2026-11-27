/// Catalogue: features/atsc/atsc.feature
library;

import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
// ignore: implementation_imports
import 'package:noports_core/src/srvd/srvd_impl.dart';
import 'package:noports_core/utils.dart';
import 'package:noports_core/version.dart' as core;
import 'package:path/path.dart' as path;
import 'package:sshnoports/src/commands/srvd.dart' as srvd;
import 'package:sshnoports/src/version.dart' as binaries;
import 'package:test/test.dart';

class _MockAtClient extends Mock implements AtClient {}

void main() {
  test('srvd reports its own name and version to relay telemetry', () async {
    binaryName = 'srvd';
    addTearDown(() => binaryName = null);
    final Directory dir = Directory.systemTemp.createTempSync('srvd_command');
    addTearDown(() => dir.deleteSync(recursive: true));
    final File keys = File(path.join(dir.path, '@relay_key.atKeys'))
      ..writeAsStringSync('{}');

    final relay = await srvd.createSrvd([
      '-a',
      '@relay',
      '-k',
      keys.path,
      '-i',
      '127.0.0.1',
      '--telemetry-collector-atsign',
      '@telemetry',
    ], (_) => _MockAtClient()) as SrvdImpl;

    final Object? version = relay.telemetry!.serviceVersion;
    expect(
      version,
      'srvd ${binaries.packageVersion} (core ${core.packageVersion})',
    );
    expect(
      version,
      matches(r'^srvd \d+\.\d+\.\d+\S* \(core \d+\.\d+\.\d+\S*\)$'),
    );
  });
}
