#!/usr/bin/env dart
// Zero-dependency atServer health probe.
//
// For each atSign: resolve its atServer address from the atDirectory, then run
// the unauthenticated `info` verb and print version + uptime. Run it BEFORE and
// AFTER a test run against the involved atSigns — if `uptimeAsWords` drops from
// days to minutes across the run, that atServer restarted mid-test (OOM/crash),
// which is a strong signal for what's breaking the older-client tests.
//
// Usage:
//   dart run atserver_info.dart [--label BEFORE] [--root-domain root.atsign.org] \
//     [--root-port 64] @sign1 @sign2 @sign3
//   (atSigns may also be comma-separated; leading @ optional)
//
// Output (one line per atSign):
//   <atSign>   <host:port>   <info json | error>

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _defaultRootHost = 'root.atsign.org';
const _defaultRootPort = 64;

/// Ask the atDirectory (root) where [atSign]'s atServer lives -> "host:port".
Future<String?> resolveSecondary(
    String atSign, String rootHost, int rootPort) async {
  final bare = atSign.startsWith('@') ? atSign.substring(1) : atSign;
  SecureSocket socket;
  try {
    socket = await SecureSocket.connect(rootHost, rootPort,
        onBadCertificate: (_) => true, timeout: const Duration(seconds: 10));
  } catch (_) {
    return null;
  }
  final completer = Completer<String?>();
  final buf = StringBuffer();
  final sub = socket.listen((d) {
    buf.write(utf8.decode(d, allowMalformed: true));
    final text = buf.toString();
    final m = RegExp(r'([a-zA-Z0-9.\-]+:\d{2,5})').firstMatch(text);
    if (m != null && !completer.isCompleted) {
      completer.complete(m.group(1));
    } else if (text.contains('null') && !completer.isCompleted) {
      completer.complete(null);
    }
  }, onError: (_) {
    if (!completer.isCompleted) completer.complete(null);
  }, onDone: () {
    if (!completer.isCompleted) completer.complete(null);
  });
  socket.write('$bare\n');
  final res = await completer.future
      .timeout(const Duration(seconds: 12), onTimeout: () => null);
  await sub.cancel();
  socket.destroy();
  return res;
}

/// Connect to [hostPort] and run the unauthenticated `info` verb.
Future<String> fetchInfo(String hostPort) async {
  final idx = hostPort.lastIndexOf(':');
  final host = hostPort.substring(0, idx);
  final port = int.tryParse(hostPort.substring(idx + 1)) ?? 0;
  SecureSocket socket;
  try {
    socket = await SecureSocket.connect(host, port,
        onBadCertificate: (_) => true, timeout: const Duration(seconds: 10));
  } catch (e) {
    return 'CONNECT_ERROR: $e';
  }
  final completer = Completer<String>();
  final buf = StringBuffer();
  final sub = socket.listen((d) {
    buf.write(utf8.decode(d, allowMalformed: true));
    final m = RegExp(r'data:(\{.*\})').firstMatch(buf.toString());
    if (m != null && !completer.isCompleted) completer.complete(m.group(1)!);
  }, onError: (e) {
    if (!completer.isCompleted) completer.complete('READ_ERROR: $e');
  }, onDone: () {
    if (!completer.isCompleted) completer.complete('NO_INFO_RESPONSE');
  });
  socket.write('info\r\n');
  final res = await completer.future
      .timeout(const Duration(seconds: 10), onTimeout: () => 'INFO_TIMEOUT');
  await sub.cancel();
  socket.destroy();
  return res;
}

Future<void> main(List<String> args) async {
  var rootHost = _defaultRootHost;
  var rootPort = _defaultRootPort;
  var label = '';
  final atSigns = <String>[];
  // Plain if/else (no switch) so the script parses under any Dart language
  // version — it is also run standalone (no pubspec) where the default
  // language version predates switch-statement implicit break.
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--root-domain') {
      rootHost = args[++i];
    } else if (a == '--root-port') {
      rootPort = int.parse(args[++i]);
    } else if (a == '--label') {
      label = args[++i];
    } else {
      atSigns.addAll(a.split(',').where((s) => s.trim().isNotEmpty));
    }
  }
  if (atSigns.isEmpty) {
    stderr.writeln('usage: dart run atserver_info.dart [--label BEFORE] '
        '[--root-domain root.atsign.org] @sign1 @sign2 ...');
    exit(2);
  }

  final ts = DateTime.now().toUtc().toIso8601String();
  print('# atServer info  label=${label.isEmpty ? "-" : label}  '
      'utc=$ts  root=$rootHost:$rootPort');
  for (final raw in atSigns) {
    final at = raw.startsWith('@') ? raw : '@$raw';
    final sec = await resolveSecondary(at, rootHost, rootPort);
    if (sec == null) {
      print('${at.padRight(38)} ${"<unresolved>".padRight(52)} -');
      continue;
    }
    final info = await fetchInfo(sec);
    print('${at.padRight(38)} ${sec.padRight(52)} $info');
  }
}
