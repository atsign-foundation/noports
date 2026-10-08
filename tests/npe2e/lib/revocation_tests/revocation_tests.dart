import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_cli_commons/at_cli_commons.dart' show getHomeDirectory;
import 'package:npe2e/apkam_setup.dart';
import 'package:npe2e/client_binary.dart';
import 'package:npe2e/client_binary_utils.dart';
import 'package:npe2e/core_tests/core_tests_docker_utils.dart'
    show ensureDockerDaemonsBuiltParallel;
import 'package:npe2e/docker_image.dart';
import 'package:npe2e/docker_instance.dart';
import 'package:npe2e/docker_utils.dart';
import 'package:npe2e/language.dart';
import 'package:npe2e/noports_version.dart';
import 'package:npe2e/process_utils.dart';
import 'package:npe2e/revocation_tests/revocation_tests_params.dart';
import 'package:npe2e/transcript.dart';
import 'package:npe2e/utils.dart';
import 'package:path/path.dart' as path;

const String revocationTestsApkamApp = 'npe2e_revocation';

/// The phrase every daemon and srvd logs when it ends a session because the
/// signing key behind it has been withdrawn
const String _withdrawnLogPhrase = 'has been withdrawn to r.__e';

/// How often the daemons and srvd under test check signing keys, in seconds
const int _keyCheckSecs = 3;

/// Runs the revocation tests: for each daemon version, a session ends once
/// its client's enrollment is revoked while a session of another enrollment
/// carries on, and an unsigned request is refused under
/// --require-enrollment-signature; and srvd ends an ESCR session once its
/// client's enrollment is revoked. Revokes the run's enrollments and stops
/// what it started, however it ends. Returns whether every test passed.
Future<bool> revocationTests(RevocationTestsParams params) async {
  final ApkamRevocations revocations = ApkamRevocations();
  final _Started started = _Started();
  try {
    return await _revocationTests(params, revocations, started);
  } finally {
    await started.stopAll();
    await revocations.revokeAll();
  }
}

/// What the run started, to stop once it is over
class _Started {
  final List<DockerInstance> containers = [];
  Process? srvd;

  Future<void> stopAll() async {
    srvd?.kill();
    await srvd?.exitCode.timeout(const Duration(seconds: 10), onTimeout: () {
      srvd?.kill(ProcessSignal.sigkill);
      return -1;
    });
    for (final DockerInstance container in containers) {
      await container.stop();
    }
  }
}

/// One enrollment of the client atSign, made for one test
class _Enrollment {
  _Enrollment(this.which, this.keysFile);

  final String which;
  final File keysFile;
}

/// A daemon container and the log it writes for its whole life
class _Daemon {
  _Daemon(this.deviceName, this.version, this.container);

  final String deviceName;
  final NoPortsVersion version;
  final DockerInstance container;

  String get log =>
      '${container.stdoutLogFile?.readAsStringSync() ?? ''}'
      '${container.stderrLogFile?.readAsStringSync() ?? ''}';
}

class _Context {
  _Context({
    required this.params,
    required this.testRunId,
    required this.transcript,
    required this.logsDirectory,
    required this.npt,
    required this.unsignedNpt,
    required this.atActivate,
    required this.srvdLog,
  });

  final RevocationTestsParams params;
  final String testRunId;
  final Transcript transcript;
  final Directory logsDirectory;
  final ClientBinary npt;
  final ClientBinary unsignedNpt;
  final ClientBinary atActivate;
  final File srvdLog;
}

Future<bool> _revocationTests(
  RevocationTestsParams params,
  ApkamRevocations revocations,
  _Started started,
) async {
  final String testRunId =
      params.testRunId ?? await getShortenedGitCommitHash();
  final Directory baseDirectory = Directory(
    path.join(params.baseDirectory, testRunId),
  );
  final Directory apkamKeysDirectory = Directory(
    path.join(baseDirectory.path, 'apkamKeys'),
  );
  final Directory logsDirectory = Directory(
    path.join(baseDirectory.path, 'logs'),
  );
  final Directory daemonLogsDirectory = Directory(
    path.join(logsDirectory.path, 'daemons'),
  );
  final Directory binariesDirectory = Directory(
    path.join(baseDirectory.path, 'binaries'),
  );
  for (final Directory d in [
    apkamKeysDirectory,
    daemonLogsDirectory,
    binariesDirectory,
  ]) {
    await ensureDirectoryExists(d);
  }
  final File transcriptFile = File(
    path.join(logsDirectory.path, 'npe2e_revocation_transcript.log'),
  );
  if (await transcriptFile.exists()) {
    await transcriptFile.delete();
  }
  final Transcript transcript = Transcript(
    tag: 'revocation_$testRunId',
    file: transcriptFile,
  );

  final List<NoPortsVersion> daemonVersions = params.daemonVersions
      .split(',')
      .map((v) => NoPortsVersion.fromLanguageVersionString(v.trim()))
      .toList();
  final NoPortsVersion current = NoPortsVersion(
    language: Language.dart,
    version: 'current',
  );
  final NoPortsVersion unsignedVersion =
      NoPortsVersion.fromLanguageVersionString(params.unsignedClientVersion);

  transcript.section('Setting up');
  final Future<List<ClientBinary>> binariesFuture = fetchClientBinariesParallel(
    // NOTE: npt -x forks the srv beside it
    clientBinariesToDownload: [
      (current, ClientBinaryType.npt),
      (current, ClientBinaryType.srv),
      (current, ClientBinaryType.at_activate),
      (current, ClientBinaryType.srvd),
      (unsignedVersion, ClientBinaryType.npt),
      (unsignedVersion, ClientBinaryType.srv),
    ],
    binariesDirectory: binariesDirectory,
  );
  final Future<List<DockerImage>> imagesFuture =
      ensureDockerDaemonsBuiltParallel(daemonVersions: daemonVersions);
  final List<ClientBinary> binaries = await binariesFuture;
  ClientBinary binary(NoPortsVersion v, ClientBinaryType t) => binaries
      .firstWhere((b) => b.binaryType == t && b.noPortsVersion == v);
  final ClientBinary atActivate = binary(current, ClientBinaryType.at_activate);

  // NOTE: one enrollment at a time, since several are of one atSign and each
  // is approved with that atSign's keys
  Future<File> enroll(String which, String atsign) async {
    revocations.add(
      atActivateClientBinary: atActivate,
      atsigns: [(which: which, atsign: atsign)],
      rootDomain: params.rootDomain,
      testRunId: testRunId,
      apkamApp: revocationTestsApkamApp,
    );
    transcript.info('Enrolling $which for $atsign');
    return setUpApkamKeyForAtsign(
      atActivateClientBinary: atActivate,
      atsign: atsign,
      which: which,
      rootDomain: params.rootDomain,
      apkamKeysDirectory: apkamKeysDirectory,
      testRunId: testRunId,
      apkamApp: revocationTestsApkamApp,
    );
  }

  final File daemonKeys = await enroll('daemon', params.daemonAtsign);
  final Map<String, _Enrollment> enrollments = {};
  Future<_Enrollment> clientEnrollment(String which) async =>
      enrollments[which] = _Enrollment(
        which,
        await enroll(which, params.clientAtsign),
      );
  for (final NoPortsVersion v in daemonVersions) {
    final String l = _short(v);
    await clientEnrollment('rv_$l');
    await clientEnrollment('kp_$l');
    await clientEnrollment('sg_$l');
  }
  await clientEnrollment('rv_relay');
  await clientEnrollment('kp_relay');

  final List<DockerImage> images = await imagesFuture;
  final List<String> addHostArgs = hostGatewayAddHostArgs();
  Future<_Daemon> startDaemon(
    NoPortsVersion version,
    String suffix,
    String flags,
  ) async {
    final DockerImage image = images.firstWhere(
      (i) => i.language == version.language && i.tag == version.version,
    );
    final String deviceName = '${testRunId}_${suffix}_${_short(version)}';
    final String keysInContainer =
        '/atsign/.atsign/keys/${path.basename(daemonKeys.path)}';
    final DockerInstance container = await runDockerInstance(
      dockerImage: image,
      testRunId: testRunId,
      logsDirectory: daemonLogsDirectory,
      uniqueIdentifier: '_rv_$suffix',
      entrypoint: [
        '/bin/bash',
        '-c',
        'sudo service ssh start && /usr/local/bin/sshnpd'
            ' -a ${params.daemonAtsign} -m ${params.clientAtsign}'
            ' -k $keysInContainer --root-domain ${params.rootDomain}'
            ' -d $deviceName -v $flags',
      ],
      volumeMappings: [
        VolumeMapping(
          local: daemonKeys.absolute.path,
          container: keysInContainer,
        ),
      ],
      additionalDockerArgs: addHostArgs,
    );
    started.containers.add(container);
    return _Daemon(deviceName, version, container);
  }

  final Map<String, _Daemon> daemons = {};
  for (final NoPortsVersion v in daemonVersions) {
    final String l = _short(v);
    daemons['dc_$l'] = await startDaemon(
      v,
      'dc',
      '--client-key-check-secs $_keyCheckSecs',
    );
    daemons['rq_$l'] = await startDaemon(
      v,
      'rq',
      '--require-enrollment-signature',
    );
  }
  daemons['rc'] = await startDaemon(current, 'rc', '--client-key-check-secs 0');
  for (final _Daemon d in daemons.values) {
    if (!await _waitForLog(() => d.log, 'monitor started', 60)) {
      transcript.error('Daemon ${d.deviceName} did not start:\n${d.log}');
      return false;
    }
  }

  final File srvdLog = File(path.join(logsDirectory.path, 'srvd.log'));
  final IOSink srvdSink = srvdLog.openWrite();
  final ClientBinary srvdBinary = binary(current, ClientBinaryType.srvd);
  final List<String> srvdArgs = [
    '-a',
    params.relayAtsign,
    '-k',
    path.join(getHomeDirectory()!, '.atsign', 'keys',
        '${params.relayAtsign}_key.atKeys'),
    '--root-domain',
    params.rootDomain,
    '--ip',
    params.relayHost,
    '--signing-key-check-secs',
    '$_keyCheckSecs',
    '-v',
  ];
  transcript.command(srvdBinary.file.path, srvdArgs);
  final Process srvd = await Process.start(srvdBinary.file.path, srvdArgs);
  started.srvd = srvd;
  srvd.stdout.listen(srvdSink.add);
  srvd.stderr.listen(srvdSink.add);
  if (!await _waitForLog(
    () => srvdLog.existsSync() ? srvdLog.readAsStringSync() : '',
    'monitor started',
    60,
  )) {
    transcript.error('srvd did not start');
    return false;
  }

  final _Context context = _Context(
    params: params,
    testRunId: testRunId,
    transcript: transcript,
    logsDirectory: logsDirectory,
    npt: binary(current, ClientBinaryType.npt),
    unsignedNpt: binary(unsignedVersion, ClientBinaryType.npt),
    atActivate: atActivate,
    srvdLog: srvdLog,
  );

  final List<(String, bool)> results = [];
  for (final NoPortsVersion v in daemonVersions) {
    final String l = _short(v);
    final _Daemon daemon = daemons['dc_$l']!;
    results.add((
      'daemon ${v.language.name}:${v.version} ends a revoked client\'s session',
      await _sessionEndsOnRevocation(
        context,
        tag: 'dc_$l',
        deviceName: daemon.deviceName,
        revoked: enrollments['rv_$l']!,
        kept: enrollments['kp_$l']!,
        relayAuthMode: 'payload',
        endedByLog: () => daemon.log,
        endedBy: 'the daemon',
      ),
    ));
    results.add((
      'daemon ${v.language.name}:${v.version} refuses an unsigned request'
          ' under --require-enrollment-signature',
      await _unsignedRefused(
        context,
        tag: 'rq_$l',
        deviceName: daemons['rq_$l']!.deviceName,
        signed: enrollments['sg_$l']!,
      ),
    ));
  }
  results.add((
    'srvd ends a revoked client\'s ESCR session',
    await _sessionEndsOnRevocation(
      context,
      tag: 'rc',
      deviceName: daemons['rc']!.deviceName,
      revoked: enrollments['rv_relay']!,
      kept: enrollments['kp_relay']!,
      relayAuthMode: 'escr',
      endedByLog: () => srvdLog.readAsStringSync(),
      endedBy: 'srvd',
    ),
  ));

  transcript.section('Results');
  for (final (String name, bool passed) in results) {
    passed ? transcript.ok('PASS $name') : transcript.error('FAIL $name');
  }
  return results.every((r) => r.$2);
}

/// A short, device-name-safe label for [v], e.g. "dc" for d:current
String _short(NoPortsVersion v) =>
    '${v.language.name.substring(0, 1)}'
    '${v.version == 'current' ? 'c' : v.version.replaceAll(RegExp('[^0-9]'), '')}';

Future<bool> _waitForLog(
  String Function() log,
  String phrase,
  int seconds,
) async {
  final DateTime giveUpAt = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(giveUpAt)) {
    if (log().contains(phrase)) {
      return true;
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
  return false;
}

/// Opens a tunnel to [deviceName]'s sshd with the client keys in [keys],
/// returning the local port it listens on, or null when npt fails, and what
/// npt printed
Future<({int? port, String output})> _openTunnel(
  _Context context,
  String tag,
  ClientBinary npt,
  String deviceName,
  File keys, {
  String? relayAuthMode,
}) async {
  final List<String> args = [
    '-f',
    context.params.clientAtsign,
    '-t',
    context.params.daemonAtsign,
    '-d',
    deviceName,
    '-r',
    context.params.relayAtsign,
    '--root-domain',
    context.params.rootDomain,
    '--remote-port',
    '22',
    '-k',
    keys.path,
    '-T',
    '60s',
    '-x',
    if (relayAuthMode != null) ...['--relay-auth-mode', relayAuthMode],
  ];
  context.transcript.withTag(tag).command(npt.file.path, args);
  final ProcessOutputCapture capture = await startCommandWithCapture(
    npt.file.path,
    args,
    stdoutLogFile: File(path.join(context.logsDirectory.path,
        '${tag}_${path.basename(keys.path)}_npt_stdout.log')),
    stderrLogFile: File(path.join(context.logsDirectory.path,
        '${tag}_${path.basename(keys.path)}_npt_stderr.log')),
    printCommand: false,
  );
  final int exitCode = await capture.exitCode.timeout(
    const Duration(seconds: 60),
    onTimeout: () {
      capture.process.kill();
      return -1;
    },
  );
  final String output = '${capture.stdout}\n${capture.stderr}';
  if (exitCode != 0) {
    context.transcript.withTag(tag).warn('npt exited $exitCode:\n$output');
    return (port: null, output: output);
  }
  return (
    port: int.tryParse(capture.stdout.trim().split('\n').last.trim()),
    output: output,
  );
}

/// Whether a fresh connection to [port] on localhost, which npt may bind on
/// IPv6 alone, reads sshd's banner within 5s
Future<bool> _bannerReadable(int port) async {
  try {
    final Socket socket = await Socket.connect(
      'localhost',
      port,
      timeout: const Duration(seconds: 5),
    );
    try {
      return await socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .any((chunk) => chunk.contains('SSH-'))
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } finally {
      socket.destroy();
    }
  } catch (_) {
    return false;
  }
}

/// A connection through a tunnel, held open, that knows when it closes
class _HeldConnection {
  _HeldConnection._(this._socket);

  final Socket _socket;
  final Completer<void> _closed = Completer<void>();
  bool _bannerSeen = false;

  bool get bannerSeen => _bannerSeen;
  bool get closed => _closed.isCompleted;

  static Future<_HeldConnection?> open(int port) async {
    try {
      final Socket socket = await Socket.connect(
        'localhost',
        port,
        timeout: const Duration(seconds: 5),
      );
      final _HeldConnection held = _HeldConnection._(socket);
      socket.listen(
        (data) {
          if (utf8.decode(data, allowMalformed: true).contains('SSH-')) {
            held._bannerSeen = true;
          }
        },
        onDone: () => held._closed.isCompleted ? null : held._closed.complete(),
        onError: (_) =>
            held._closed.isCompleted ? null : held._closed.complete(),
        cancelOnError: true,
      );
      return held;
    } catch (_) {
      return null;
    }
  }

  void close() => _socket.destroy();
}

/// Opens two tunnels to [deviceName], one with each of [revoked] and [kept],
/// revokes [revoked], and checks that its tunnel ends within the allowed
/// time, that [endedBy]'s log says why, and that the other tunnel carries on
Future<bool> _sessionEndsOnRevocation(
  _Context context, {
  required String tag,
  required String deviceName,
  required _Enrollment revoked,
  required _Enrollment kept,
  required String relayAuthMode,
  required String Function() endedByLog,
  required String endedBy,
}) async {
  final Transcript t = context.transcript.withTag(tag);
  t.section('$endedBy ends the session of a revoked enrollment ($deviceName)');
  final int? revokedPort = (await _openTunnel(
          context, tag, context.npt, deviceName, revoked.keysFile,
          relayAuthMode: relayAuthMode))
      .port;
  final int? keptPort = (await _openTunnel(
          context, tag, context.npt, deviceName, kept.keysFile,
          relayAuthMode: relayAuthMode))
      .port;
  if (revokedPort == null || keptPort == null) {
    t.error('Could not open both tunnels');
    return false;
  }
  final _HeldConnection? revokedHeld = await _HeldConnection.open(revokedPort);
  final _HeldConnection? keptHeld = await _HeldConnection.open(keptPort);
  try {
    await Future.delayed(const Duration(seconds: 2));
    if (revokedHeld == null ||
        keptHeld == null ||
        !revokedHeld.bannerSeen ||
        !keptHeld.bannerSeen ||
        !await _bannerReadable(revokedPort) ||
        !await _bannerReadable(keptPort)) {
      t.error('A tunnel did not reach sshd before the revocation');
      return false;
    }
    t.ok('Both tunnels reach sshd');
    final int logLengthBefore = endedByLog().length;

    final List<String> revokeArgs = [
      'revoke',
      '-a',
      context.params.clientAtsign,
      '-r',
      context.params.rootDomain,
      '--arx',
      revocationTestsApkamApp,
      '--drx',
      getApkamDeviceName(which: revoked.which, testRunId: context.testRunId),
    ];
    t.command(context.atActivate.file.path, revokeArgs);
    final ProcessResult revoke = await runCommand(
      context.atActivate.file.path,
      revokeArgs,
      printCommand: false,
    );
    if (revoke.exitCode != 0) {
      t.error('Could not revoke ${revoke.stderr}');
      return false;
    }
    final Stopwatch sinceRevoke = Stopwatch()..start();
    t.info('Revoked ${revoked.which}');

    final Duration allowed = Duration(
      seconds: context.params.withdrawnWithinSeconds,
    );
    bool ended = false;
    while (sinceRevoke.elapsed < allowed) {
      if (revokedHeld.closed && !await _bannerReadable(revokedPort)) {
        ended = true;
        break;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    final String logSince = endedByLog().substring(logLengthBefore);
    final bool logged = logSince.contains(_withdrawnLogPhrase);
    final bool keptAlive =
        !keptHeld.closed && await _bannerReadable(keptPort);
    if (ended) {
      t.ok('The revoked enrollment\'s tunnel ended after'
          ' ${sinceRevoke.elapsed.inSeconds}s');
    } else {
      t.error('The revoked enrollment\'s tunnel was still up after'
          ' ${allowed.inSeconds}s (held connection closed:'
          ' ${revokedHeld.closed})');
    }
    if (logged) {
      t.ok('$endedBy logged "$_withdrawnLogPhrase"');
    } else {
      t.error('$endedBy did not log "$_withdrawnLogPhrase"; its log since the'
          ' revocation:\n$logSince');
    }
    if (keptAlive) {
      t.ok('The other enrollment\'s tunnel carried on');
    } else {
      t.error('The other enrollment\'s tunnel ended too');
    }
    return ended && logged && keptAlive;
  } finally {
    revokedHeld?.close();
    keptHeld?.close();
  }
}

/// Checks that [deviceName], a daemon run with
/// --require-enrollment-signature, refuses a request from a released client
/// that doesn't sign it, and accepts one from the current client
Future<bool> _unsignedRefused(
  _Context context, {
  required String tag,
  required String deviceName,
  required _Enrollment signed,
}) async {
  final Transcript t = context.transcript.withTag(tag);
  t.section('$deviceName requires an enrollment signature');
  final (port: int? unsignedPort, output: String unsignedOutput) =
      await _openTunnel(
          context, tag, context.unsignedNpt, deviceName, signed.keysFile);
  final bool refused = unsignedPort == null &&
      unsignedOutput.contains('requires session requests signed');
  if (refused) {
    t.ok('The unsigned request was refused, and npt said why');
  } else {
    t.error('The unsigned request was not refused as expected'
        ' (local port $unsignedPort):\n$unsignedOutput');
  }
  final int? signedPort = (await _openTunnel(
          context, tag, context.npt, deviceName, signed.keysFile))
      .port;
  final bool accepted =
      signedPort != null && await _bannerReadable(signedPort);
  if (accepted) {
    t.ok('The signed request was accepted');
  } else {
    t.error('The signed request was not accepted');
  }
  return refused && accepted;
}
