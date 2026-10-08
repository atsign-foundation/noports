import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:at_client/at_client.dart';
import 'package:at_lookup/at_lookup.dart'
    show
        CacheableSecondaryAddressFinder,
        SecondaryAddress,
        SecondaryAddressFinder;
import 'package:at_utils/at_logger.dart';
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
/// the atDirectory gives for it. Each lookup has its own connection and a
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
    this.maxConcurrent = defaultMaxConcurrent,
    this.maxPerAtSign = defaultMaxPerAtSign,
    @visibleForTesting this.scheme = 'https',
  }) : _addressFinder = addressFinder;

  static const defaultTimeout = Duration(seconds: 10);
  static const defaultMaxConcurrent = 16;
  static const defaultMaxPerAtSign = 2;

  /// The most a record's value may be, which no `_apsk` advertisement or
  /// public key comes near.
  static const maxValueBytes = 64 * 1024;

  final AtClient atClient;
  final Duration timeout;
  final int maxConcurrent;
  final int maxPerAtSign;
  final String scheme;

  final AtSignLogger logger = AtSignLogger(' DirectPublicLookup ');

  final SecondaryAddressFinder? _addressFinder;

  late final SecondaryAddressFinder _finder = _addressFinder ??
      CacheableSecondaryAddressFinder(
        atClient.getPreferences()!.rootDomain,
        atClient.getPreferences()!.rootPort,
      );

  late final HttpClient _client = HttpClient()
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
        return await _get(atSign, key);
      } finally {
        _all.release();
      }
    } finally {
      slots.release();
      if (slots.idle) _byAtSign.remove(atSign);
    }
  }

  Future<String?> _get(String atSign, String key) async {
    final SecondaryAddress address;
    try {
      address = await _finder.findSecondary(atSign, timeout: timeout);
    } catch (e) {
      throw _NotServedOverHttp(
        'The atDirectory has no address for $atSign: $e',
      );
    }
    final url = Uri(
      scheme: scheme,
      host: address.host,
      port: address.port,
      pathSegments: [atSign, key],
    );
    HttpClientRequest? request;
    try {
      return await () async {
        request = await _client.getUrl(url);
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
          .timeout(timeout);
    } on TimeoutException {
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
