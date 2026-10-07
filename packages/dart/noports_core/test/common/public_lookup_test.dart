import 'dart:async';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_lookup/at_lookup.dart'
    show SecondaryAddress, SecondaryAddressFinder;
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/public_lookup.dart';
import 'package:test/test.dart';

import '../sshnp/sshnp_mocks.dart';

/// Finds every atSign in [ports] on the loopback address.
class _LoopbackFinder implements SecondaryAddressFinder {
  _LoopbackFinder(this.ports);

  final Map<String, int> ports;

  @override
  Future<SecondaryAddress> findSecondary(String atSign, {Duration? timeout}) {
    final port = ports[atSign];
    return port == null
        ? Future.error(SecondaryNotFoundException('$atSign is not here'))
        : Future.value(SecondaryAddress('127.0.0.1', port));
  }
}

void main() {
  late MockAtClient atClient;
  late Map<String, int> ports;

  setUp(() {
    registerFallbackValue(AtKey());
    registerFallbackValue(GetRequestOptions());
    atClient = MockAtClient();
    ports = {};
  });

  DirectPublicLookup lookupWith({
    Duration timeout = const Duration(seconds: 5),
    int maxConcurrent = 16,
    int maxPerAtSign = 2,
  }) {
    final lookup = DirectPublicLookup(
      atClient,
      addressFinder: _LoopbackFinder(ports),
      timeout: timeout,
      maxConcurrent: maxConcurrent,
      maxPerAtSign: maxPerAtSign,
      scheme: 'http',
    );
    addTearDown(lookup.close);
    return lookup;
  }

  /// An atServer for [atSign] answering each GET with what [answer] gives
  /// for its path, and recording each path it was asked for.
  Future<List<String>> serve(
    String atSign,
    FutureOr<(int, String)> Function(String path) answer,
  ) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    ports[atSign] = server.port;
    final asked = <String>[];
    server.listen((request) async {
      asked.add(request.uri.path);
      final (status, body) = await answer(request.uri.path);
      request.response
        ..statusCode = status
        ..write(body);
      await request.response.close();
    });
    return asked;
  }

  /// An atServer for [atSign] that takes connections and never answers,
  /// returning how many it has taken.
  Future<int Function()> serveSilently(String atSign) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final held = <Socket>[];
    addTearDown(() async {
      for (final socket in held) {
        socket.destroy();
      }
      await server.close();
    });
    ports[atSign] = server.port;
    server.listen(held.add);
    return () => held.length;
  }

  /// An atServer for [atSign] that answers in atProtocol, not HTTP, as one
  /// from before HTTP GET does.
  Future<void> serveAtProtocol(String atSign) async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(server.close);
    ports[atSign] = server.port;
    server.listen((socket) {
      socket.write('error:AT0003-Invalid syntax\n');
      socket.destroy();
    });
  }

  void ownAtServerHolds(String uri, String value) => when(
        () => atClient.get(
          any(that: predicate<AtKey>((k) => k.toString() == uri)),
          getRequestOptions: any(named: 'getRequestOptions'),
        ),
      ).thenAnswer((_) async => AtValue()..value = value);

  const aliceKey = 'public:_apsk.alice-enrollment.a.__e@alice';

  group('lookup and lookupDirect', () {
    test("return the value the record's atServer serves at /<atSign>/<key>",
        () async {
      final asked = await serve('@alice', (_) => (200, 'a public key'));

      expect(await lookupWith().lookupDirect(aliceKey), 'a public key');
      expect(await lookupWith().lookup(aliceKey), 'a public key');
      expect(asked, everyElement('/@alice/_apsk.alice-enrollment.a.__e'));
    });

    test('return null when the atServer answers 404', () async {
      await serve('@alice', (_) => (404, '404 Not Found'));

      expect(await lookupWith().lookupDirect(aliceKey), isNull);
      expect(await lookupWith().lookup(aliceKey), isNull);
      verifyNever(() => atClient.get(any(),
          getRequestOptions: any(named: 'getRequestOptions')));
    });

    test("lookup asks the client's own atServer when the record's atServer"
        " doesn't answer over HTTP, and lookupDirect doesn't", () async {
      await serveAtProtocol('@alice');
      ownAtServerHolds(aliceKey, 'from my own atServer');

      expect(await lookupWith().lookup(aliceKey), 'from my own atServer');
      await expectLater(lookupWith().lookupDirect(aliceKey), throwsA(anything));
      verify(() => atClient.get(any(),
          getRequestOptions: any(named: 'getRequestOptions'))).called(1);
    });

    test("lookup asks the client's own atServer when the record's atServer"
        ' refuses the connection, and lookupDirect does not', () async {
      final closed = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      ports['@alice'] = closed.port;
      await closed.close();
      ownAtServerHolds(aliceKey, 'from my own atServer');

      expect(await lookupWith().lookup(aliceKey), 'from my own atServer');
      await expectLater(lookupWith().lookupDirect(aliceKey), throwsA(anything));
    });

    test("lookup asks the client's own atServer when the atDirectory has no"
        ' address for the atSign, and lookupDirect does not', () async {
      ownAtServerHolds(aliceKey, 'from my own atServer');

      expect(await lookupWith().lookup(aliceKey), 'from my own atServer');
      await expectLater(lookupWith().lookupDirect(aliceKey), throwsA(anything));
    });

    test('give up on a silent atServer at the deadline, without asking the'
        " client's own atServer", () async {
      await serveSilently('@mallory');
      final lookup =
          lookupWith(timeout: const Duration(milliseconds: 300));

      await expectLater(
        lookup.lookupDirect('public:_apsk.m.a.__e@mallory'),
        throwsA(isA<TimeoutException>()),
      );
      await expectLater(
        lookup.lookup('public:_apsk.m.a.__e@mallory'),
        throwsA(isA<TimeoutException>()),
      );
      verifyNever(() => atClient.get(any(),
          getRequestOptions: any(named: 'getRequestOptions')));
    });

    test("a silent atServer doesn't delay a lookup on another atServer",
        () async {
      await serveSilently('@mallory');
      await serve('@alice', (_) => (200, 'a public key'));
      final lookup = lookupWith(timeout: const Duration(seconds: 5));
      final stalled = [
        for (var i = 0; i < 4; i++)
          lookup.lookupDirect('public:_apsk.m$i.a.__e@mallory'),
      ];
      for (final s in stalled) {
        unawaited(s.catchError((_) => null));
      }

      final timer = Stopwatch()..start();
      expect(await lookup.lookupDirect(aliceKey), 'a public key');
      expect(timer.elapsed, lessThan(const Duration(seconds: 2)));
    });

    test('ask one atServer at most maxPerAtSign at a time', () async {
      final taken = await serveSilently('@mallory');
      final lookup = lookupWith(
        timeout: const Duration(seconds: 2),
        maxPerAtSign: 2,
      );
      for (var i = 0; i < 5; i++) {
        unawaited(lookup
            .lookupDirect('public:_apsk.m$i.a.__e@mallory')
            .then((_) => null, onError: (_) => null));
      }

      await Future.delayed(const Duration(milliseconds: 500));
      expect(taken(), 2);
    });

    test('ask at most maxConcurrent atServers at a time', () async {
      final takenByMallory = await serveSilently('@mallory');
      final takenByEve = await serveSilently('@eve');
      final asked = await serve('@alice', (_) => (200, 'a public key'));
      final lookup = lookupWith(
        timeout: const Duration(seconds: 1),
        maxConcurrent: 2,
        maxPerAtSign: 1,
      );
      for (final atSign in ['@mallory', '@eve']) {
        unawaited(lookup
            .lookupDirect('public:_apsk.m.a.__e$atSign')
            .then((_) => null, onError: (_) => null));
      }
      await Future.delayed(const Duration(milliseconds: 200));
      final alice = lookup.lookupDirect(aliceKey);

      await Future.delayed(const Duration(milliseconds: 300));
      expect(asked, isEmpty, reason: 'both slots are held by silent lookups');
      expect(takenByMallory() + takenByEve(), 2);
      expect(await alice, 'a public key');
    });

    test("don't follow a redirect", () async {
      final elsewhere = await serve('@elsewhere', (_) => (200, 'elsewhere'));
      await serve(
        '@alice',
        (_) => (HttpStatus.found, ''),
      );
      final lookup = lookupWith();

      await expectLater(lookup.lookupDirect(aliceKey),
          throwsA(predicate((e) => '$e'.contains('answered 302'))));
      expect(elsewhere, isEmpty);
    });

    test('refuse a value over maxValueBytes', () async {
      await serve('@alice',
          (_) => (200, 'x' * (DirectPublicLookup.maxValueBytes + 1)));

      await expectLater(
        lookupWith().lookupDirect(aliceKey),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('withdrawnTo', () {
    Future<void> holding(Set<String> locations) => serve('@alice', (path) {
          final location = path.split('.').reversed.skip(1).first;
          return locations.contains('$location.__e')
              ? (200, 'a public key')
              : (404, '404 Not Found');
        });

    test('finds a revoked enrollment', () async {
      await holding({'r.__e'});
      expect(await lookupWith().withdrawnTo(aliceKey), 'r.__e');
    });

    test('finds a deleted enrollment', () async {
      await holding({'d.__e'});
      expect(await lookupWith().withdrawnTo(aliceKey), 'd.__e');
    });

    test('finds neither when the enrollment is merely missing', () async {
      await holding({});
      expect(await lookupWith().withdrawnTo(aliceKey), isNull);
    });

    test("throws when it can't tell", () async {
      await serveSilently('@alice');
      await expectLater(
        lookupWith(timeout: const Duration(milliseconds: 300))
            .withdrawnTo(aliceKey),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
