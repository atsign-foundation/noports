import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_lookup/at_lookup_io.dart'
    show
        CacheableSecondaryAddressFinder,
        SecondaryAddress,
        SecondaryAddressFinder;
import 'package:meta/meta.dart';

/// Looks up atSigns' public records, such as the `_apsk` records that
/// enrollments publish their signing keys in.
abstract class PublicLookup {
  /// The value of the public record [uri] (`public:<key>@<atSign>`), or null
  /// when its atServer doesn't hold it. Throws when that can't be told.
  Future<String?> lookup(String uri);

  /// As [lookup], but asking only the atServer that holds [uri], so that a
  /// slow or silent atServer can't delay anything else this process does.
  Future<String?> lookupDirect(String uri);

  /// Where the `_apsk` record [uri], lower-cased
  /// `public:_apsk.<enrollmentId>.a.__e@<atSign>`, has been withdrawn to:
  /// `r.__e` when its enrollment was revoked or superseded, `d.__e` when it
  /// was deleted or expired; null when neither holds it. Throws when that
  /// can't be told.
  Future<String?> withdrawnTo(String uri) async {
    final match = _apskUri.firstMatch(uri);
    if (match == null) return null;
    final [revoked, deleted] = await Future.wait([
      for (final location in [
        EnrollmentConstants.perEnrollmentRevoked,
        EnrollmentConstants.perEnrollmentDeleted,
      ])
        _held('public:_apsk.${match.group(1)}.$location${match.group(2)}'),
    ]);
    if (revoked case (held: true, error: _)) {
      return EnrollmentConstants.perEnrollmentRevoked;
    }
    if (deleted case (held: true, error: _)) {
      return EnrollmentConstants.perEnrollmentDeleted;
    }
    if (revoked.error ?? deleted.error case final Object error) throw error;
    return null;
  }

  Future<({bool held, Object? error})> _held(String uri) async {
    try {
      return (held: await lookupDirect(uri) != null, error: null);
    } catch (e) {
      return (held: false, error: e);
    }
  }

  /// Releases whatever lookups hold open.
  void close() {}

  static final _apskUri = RegExp(
    '^public:_apsk\\.([a-z0-9_-]+)'
    '\\.${RegExp.escape(EnrollmentConstants.perEnrollmentApproved)}'
    '(@[^@:\\s]+)\$',
  );
}

/// A [PublicLookup] that asks each record's own atServer, over the HTTPS GET
/// (`/<atSign>/<key>`) that atServers serve public records on, at the address
/// the atDirectory gives for it, offering `http/1.1` by ALPN, without which an
/// atServer answers in atProtocol. Each lookup has its own connection and a
/// deadline, at most [maxPerAtSign] of them run at once for any one atSign,
/// and at most [maxConcurrent] in all.
///
/// [lookup] falls back to [atClient]'s own atServer when the record's
/// atServer can't be connected to, or doesn't answer over HTTP as an
/// atServer from before HTTP GET doesn't; [lookupDirect] never does, and
/// neither does once a connection was made and then went unanswered.
class DirectPublicLookup extends PublicLookup {
  DirectPublicLookup(
    this.atClient, {
    SecondaryAddressFinder? addressFinder,
    this.timeout = defaultTimeout,
    this.timeoutCoversAddress = false,
    this.maxConcurrent = defaultMaxConcurrent,
    this.maxPerAtSign = defaultMaxPerAtSign,
    this.onAnswered,
    @visibleForTesting this.scheme = 'https',
    @visibleForTesting SecurityContext? securityContext,
  })  : _addressFinder = addressFinder,
        _addressesFrom = null,
        _securityContext = securityContext;

  DirectPublicLookup._sharing(
    DirectPublicLookup other, {
    required this.timeout,
    required this.timeoutCoversAddress,
    required this.maxConcurrent,
    required this.maxPerAtSign,
    required this.onAnswered,
  })  : atClient = other.atClient,
        scheme = other.scheme,
        _addressFinder = null,
        _addressesFrom = other,
        _securityContext = other._securityContext;

  /// A lookup that finds atServers' addresses through this one's finder, so
  /// the two share one cache of what the atDirectory answered, and reaches
  /// them as this one does, with connections, a deadline and limits of its
  /// own.
  DirectPublicLookup sharingAddresses({
    required Duration timeout,
    bool timeoutCoversAddress = false,
    int? maxConcurrent,
    int? maxPerAtSign,
    void Function(String uri, Duration took)? onAnswered,
  }) =>
      DirectPublicLookup._sharing(
        this,
        timeout: timeout,
        timeoutCoversAddress: timeoutCoversAddress,
        maxConcurrent: maxConcurrent ?? this.maxConcurrent,
        maxPerAtSign: maxPerAtSign ?? this.maxPerAtSign,
        onAnswered: onAnswered,
      );

  static const defaultTimeout = Duration(seconds: 10);
  static const defaultMaxConcurrent = 16;
  static const defaultMaxPerAtSign = 2;

  /// The most a record's value may be, which no `_apsk` advertisement or
  /// public key comes near.
  static const maxValueBytes = 64 * 1024;

  final AtClient atClient;

  /// How long finding a record's atServer may take, and how long that
  /// atServer then has to answer.
  final Duration timeout;

  /// Whether [timeout] is for the two together, so that a lookup ends
  /// within it once it has begun.
  final bool timeoutCoversAddress;
  final int maxConcurrent;
  final int maxPerAtSign;

  /// Told each record an atServer answered for, held or not, and how long
  /// that took from the lookup's turn coming, the wait for a turn left out.
  final void Function(String uri, Duration took)? onAnswered;
  final String scheme;

  final AtSignLogger logger = AtSignLogger(' DirectPublicLookup ');

  final SecondaryAddressFinder? _addressFinder;
  final DirectPublicLookup? _addressesFrom;
  final SecurityContext? _securityContext;

  late final SecondaryAddressFinder _finder = _addressFinder ??
      _addressesFrom?._finder ??
      CacheableSecondaryAddressFinder(
        atClient.getPreferences()!.rootDomain,
        atClient.getPreferences()!.rootPort,
      );

  // NOTE: an atServer answers a TLS connection over HTTP only when ALPN
  // selects http/1.1, and HttpClient offers no ALPN of its own
  late final HttpClient _client = HttpClient(
    context: (_securityContext ?? SecurityContext(withTrustedRoots: true))
      ..setAlpnProtocols(['http/1.1'], false),
  )
    ..connectionTimeout = timeout ~/ 2
    ..idleTimeout = const Duration(seconds: 15);

  late final _Slots _all = _Slots(maxConcurrent);
  final Map<String, _Slots> _byAtSign = {};

  @override
  Future<String?> lookup(String uri) async {
    try {
      return await lookupDirect(uri);
    } on _NotServedOverHttp catch (e) {
      logger.info('$e, so asking this client\'s own atServer for $uri');
    }
    try {
      final value = (await atClient.get(
        AtKey.fromString(uri),
        getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
      ))
          .value;
      return value is String ? value : null;
    } on AtKeyNotFoundException {
      return null;
    }
  }

  @override
  Future<String?> lookupDirect(String uri) async {
    if (!uri.startsWith('public:') || !uri.contains('@')) {
      throw ArgumentError.value(uri, 'uri', 'is not public:<key>@<atSign>');
    }
    final at = uri.lastIndexOf('@');
    final atSign = uri.substring(at);
    final key = uri.substring('public:'.length, at);
    final slots = _byAtSign.putIfAbsent(atSign, () => _Slots(maxPerAtSign));
    await slots.acquire();
    try {
      await _all.acquire();
      try {
        final Stopwatch took = Stopwatch()..start();
        final String? value = await _get(atSign, key);
        onAnswered?.call(uri, took.elapsed);
        return value;
      } finally {
        _all.release();
      }
    } finally {
      slots.release();
      if (slots.idle) _byAtSign.remove(atSign);
    }
  }

  Future<String?> _get(String atSign, String key) async {
    final Stopwatch finding = Stopwatch()..start();
    final SecondaryAddress address;
    try {
      address = await _finder.findSecondary(atSign, timeout: timeout);
    } catch (e) {
      throw _NotServedOverHttp(
        'The atDirectory has no address for $atSign: $e',
      );
    }
    final Duration left =
        timeoutCoversAddress ? timeout - finding.elapsed : timeout;
    if (left <= Duration.zero) {
      throw TimeoutException('Finding the atServer of $atSign', timeout);
    }
    final url = Uri(
      scheme: scheme,
      host: address.host,
      port: address.port,
      pathSegments: [atSign, key],
    );
    HttpClientRequest? request;
    bool gaveUp = false;
    try {
      return await () async {
        final HttpClientRequest connected = await _client.getUrl(url);
        // NOTE: a connection made after the deadline is closed here, since
        // nothing waits for its answer any more
        if (gaveUp) {
          connected.abort();
          return null;
        }
        request = connected;
        request!.followRedirects = false;
        final response = await request!.close();
        switch (response.statusCode) {
          case HttpStatus.ok:
            return await _body(response, url);
          case HttpStatus.notFound:
            await response.drain<void>();
            return null;
          default:
            await response.drain<void>();
            throw _NotServedOverHttp('$url answered ${response.statusCode}');
        }
      }()
          .timeout(left);
    } on TimeoutException {
      gaveUp = true;
      request?.abort();
      rethrow;
    } on HttpException catch (e) {
      throw _NotServedOverHttp('$url did not answer over HTTP: $e');
    } on TlsException catch (e) {
      throw _NotServedOverHttp('$url could not be verified: $e');
    } on SocketException catch (e) {
      throw _NotServedOverHttp('$url could not be connected to: $e');
    }
  }

  Future<String> _body(HttpClientResponse response, Uri url) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > maxValueBytes) {
        throw FormatException('$url answered more than $maxValueBytes bytes');
      }
    }
    return utf8.decode(bytes);
  }

  @override
  void close() => _client.close(force: true);
}

/// A record's atServer couldn't be found, connected to or trusted, or didn't
/// answer over HTTP, so asking it some other way might still work.
class _NotServedOverHttp implements Exception {
  _NotServedOverHttp(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A count of [max] slots, which [acquire] waits for in turn.
class _Slots {
  _Slots(this.max);

  final int max;
  int _held = 0;
  final Queue<Completer<void>> _waiting = Queue();

  bool get idle => _held == 0 && _waiting.isEmpty;

  Future<void> acquire() async {
    if (_held < max) {
      _held++;
      return;
    }
    final turn = Completer<void>();
    _waiting.add(turn);
    await turn.future;
  }

  /// Hands this slot to the longest waiter, if there is one.
  void release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
    } else {
      _held--;
    }
  }
}
