import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:at_chops/at_chops.dart';
import 'package:at_cli_commons/at_cli_commons.dart';
import 'package:at_client/at_client.dart' hide StringBuffer;
import 'package:at_lookup/at_lookup.dart';
import 'package:uuid/uuid.dart';

/// An atServer for every atSign in a test, on in-memory sockets in this
/// process, so the clients above it run their real command building, framing,
/// authentication and monitor code.
///
/// A command no handler understands is answered with an error and recorded in
/// [unhandled], so a client behaviour the fake doesn't model shows up as a
/// failure naming the verb rather than as a silent wrong answer.
class FakeAtServer {
  final Map<String, FakeAtSign> _atSigns = {};

  /// Commands no handler understood, as received.
  final List<String> unhandled = [];

  /// Every connection opened so far, oldest first.
  final List<FakeConnection> connections = [];

  /// The atSign called [atSign], created with an approved first enrollment.
  FakeAtSign addAtSign(String atSign) {
    final name = atSign.toAtsign();
    if (_atSigns.containsKey(name)) {
      throw StateError('$name is already served by this FakeAtServer');
    }
    return _atSigns[name] = FakeAtSign._(this, name, _atSigns.length + 1);
  }

  /// The atSign called [atSign], which must have been added.
  FakeAtSign operator [](String atSign) =>
      _atSigns[atSign.toAtsign()] ??
      (throw StateError('$atSign is not served by this FakeAtServer'));

  FakeAtSign? _find(String atSign) => _atSigns[atSign.toAtsign()];

  /// Builds every connection a client opens, onto this server.
  AtLookUpFactory get lookUps => ({
        required String atSign,
        required AtRootDomain rootDomain,
        required AtAuthenticator? authenticator,
        SecondaryAddressFinder? secondaryAddressFinder,
        Map<String, dynamic> clientConfig = const {},
      }) =>
          AtLookUp.withSecureSocket(
            atSign: atSign,
            rootDomain: rootDomain,
            authenticator: authenticator,
            // NOTE this server's own: the caller's would ask the real
            // atDirectory.
            secondaryAddressFinder: addressFinder,
            clientConfig: clientConfig,
            transport: AtLookupTransport(
              secureSocketConfig: SecureSocketConfig(),
              socketFactory: _FakeSocketFactory(this),
            ),
          );

  /// The atDirectory: every atSign this server holds, on a port of its own.
  late final SecondaryAddressFinder addressFinder = _FakeAddressFinder(this);

  /// Services for a client on this server: no sync, and a notification
  /// service that finds atServers here rather than in the real atDirectory.
  late final AtServiceFactory serviceFactory = _FakeServiceFactory(this);

  FakeConnection _connect(String host, String port) {
    final atSign = _atSigns.values.where((a) => '${a.port}' == port);
    if (host != _host || atSign.isEmpty) {
      throw SocketException('no fake atServer at $host:$port');
    }
    final connection = FakeConnection._(atSign.single);
    connections.add(connection);
    return connection;
  }

  static const _host = 'fake.atserver.test';
}

/// One atSign this [FakeAtServer] serves: its key store, enrollments and
/// notifications.
class FakeAtSign {
  FakeAtSign._(this.server, this.atSign, this.port) {
    _store('public:publickey$atSign',
        FakeRecord(encryptionKeyPair.atPublicKey.publicKey, _newMetadata()));
    firstEnrollment = enroll(
      appName: 'fake_atserver',
      deviceName: 'first',
      namespaces: const {'__manage': 'rw', '*': 'rw'},
    );
  }

  final FakeAtServer server;
  final String atSign;
  final int port;

  final RsaKeyPair encryptionKeyPair = RsaKeyPair.generate();
  final String selfEncryptionKey = AESKey.generate(32).key;
  final Map<String, FakeRecord> _keyStore = {};
  final Map<String, FakeEnrollment> enrollments = {};

  /// Notifications this atSign has received, oldest first.
  final List<FakeNotification> received = [];

  /// The final status of each notification this atSign has sent, by id.
  final Map<String, String> sentStatus = {};

  final List<FakeConnection> _monitors = [];
  int _commitId = 0;

  /// The approved enrollment every atSign starts with, granted everything.
  late final FakeEnrollment firstEnrollment;

  /// An approved enrollment of this atSign with [namespaces].
  FakeEnrollment enroll({
    required String appName,
    required String deviceName,
    required Map<String, String> namespaces,
  }) {
    final keyPair = RsaKeyPair.generate();
    final enrollment = FakeEnrollment._(
      this,
      Uuid().v4(),
      appName: appName,
      deviceName: deviceName,
      namespaces: namespaces,
      apkamPublicKey: keyPair.atPublicKey.publicKey,
      apkamKeyPair: keyPair,
    );
    return enrollments[enrollment.id] = enrollment;
  }

  /// The record stored under [key], or null.
  FakeRecord? recordAt(String key) => _keyStore[key.toLowerCase()];

  void _store(String key, FakeRecord record) =>
      _keyStore[key.toLowerCase()] = record;

  int _commit(String key) {
    final k = key.toLowerCase();
    final uncommitted = k.startsWith('private:') ||
        k.startsWith('privatekey:') ||
        k.startsWith('local:') ||
        (k.startsWith('public:_') && !k.startsWith('public:__'));
    return uncommitted ? -1 : _commitId++;
  }

  Map<String, dynamic> _newMetadata() {
    final now = _timestamp(DateTime.now());
    return {
      'createdBy': atSign,
      'updatedBy': atSign,
      'createdAt': now,
      'updatedAt': now,
      'status': 'active',
      'version': 0,
      'isBinary': false,
      'isEncrypted': false,
      'immutable': false,
    };
  }

  void _receive(FakeNotification notification) {
    if (received.any((n) => n.id == notification.id)) return;
    received.add(notification);
    if (notification.ttr != null &&
        notification.operation == 'update' &&
        notification.value != null) {
      final metadata = _newMetadata()
        ..['createdBy'] = notification.from
        ..['updatedBy'] = notification.from
        ..['ttr'] = notification.ttr
        ..['ccd'] = notification.ccd
        ..['isEncrypted'] = notification.isEncrypted;
      _store('cached:${notification.key}',
          FakeRecord(notification.value!, metadata));
    }
    for (final monitor in [..._monitors]) {
      monitor._deliver(notification);
    }
  }
}

/// An APKAM enrollment of a [FakeAtSign]: the public key it authenticates
/// with, and that key's algorithm.
class FakeEnrollment {
  FakeEnrollment._(
    this.atSign,
    this.id, {
    required this.appName,
    required this.deviceName,
    required this.namespaces,
    required this.apkamPublicKey,
    this.signingAlgo = 'rsa2048',
    this.retrofitPredecessor,
    this.metadata,
    RsaKeyPair? apkamKeyPair,
  }) : _apkamKeyPair = apkamKeyPair;

  final FakeAtSign atSign;
  final String id;
  final String appName;
  final String deviceName;
  final Map<String, String> namespaces;

  /// Base64, as the client sent it in `enroll:request`.
  final String apkamPublicKey;
  final String signingAlgo;

  /// The enrollment this one replaced with a stronger key, if any.
  final FakeEnrollment? retrofitPredecessor;

  Map<String, dynamic>? metadata;
  String status = 'approved';
  DateTime? revokedAt;
  DateTime? predecessorSettledAt;

  /// The private half, held only for an enrollment this fake minted.
  final RsaKeyPair? _apkamKeyPair;

  bool get _isRoot =>
      namespaces['*'] == 'rw' && namespaces['__manage'] == 'rw';

  /// The keys a client authenticating as this enrollment holds.
  AtKeys get keys => _keysFor(
      _apkamKeyPair ?? (throw StateError('$id has no private half here')));

  AtKeys _keysFor(RsaKeyPair apkamKeyPair) => AtKeys()
    // ignore: deprecated_member_use
    ..apkamPublicKey = AtBytes.fromString(apkamKeyPair.atPublicKey.publicKey)
    // ignore: deprecated_member_use
    ..apkamPrivateKey = AtBytes.fromString(apkamKeyPair.atPrivateKey.privateKey)
    // ignore: deprecated_member_use
    ..defaultEncryptionPublicKey =
        AtBytes.fromString(atSign.encryptionKeyPair.atPublicKey.publicKey)
    // ignore: deprecated_member_use
    ..defaultEncryptionPrivateKey =
        AtBytes.fromString(atSign.encryptionKeyPair.atPrivateKey.privateKey)
    // ignore: deprecated_member_use
    ..defaultSelfEncryptionKey = AtBytes.fromString(atSign.selfEncryptionKey)
    // ignore: deprecated_member_use
    ..enrollmentId = id;

  /// Revokes this enrollment: its live connections close at once, and its
  /// `<id>.a.__e` records move to `<id>.r.__e`, so its published signing key
  /// is no longer found.
  void revoke() {
    status = 'revoked';
    revokedAt = DateTime.now().toUtc();
    final approved = RegExp('(^|[.:])${RegExp.escape(id)}\\.a\\.__e@');
    final store = atSign._keyStore;
    for (final key in store.keys.where(approved.hasMatch).toList()) {
      store[key.replaceFirst('.a.__e@', '.r.__e@')] = store.remove(key)!;
    }
    for (final c in atSign.server.connections) {
      if (c.enrollment == this) c._close();
    }
  }
}

extension on FakeEnrollment {
  String get _recordKey => '$id.new.enrollments.__manage${atSign.atSign}';

  Map<String, dynamic> _roster() => {
        'appName': appName,
        'deviceName': deviceName,
        'namespaces': namespaces,
        'namespace': namespaces,
        'approval': {'state': status},
        'status': status,
        if (signingAlgo != 'rsa2048') 'signingAlgo': signingAlgo,
        if (retrofitPredecessor != null)
          'retrofitPredecessorEnrollmentId': retrofitPredecessor!.id,
        if (predecessorSettledAt != null)
          'predecessorSettledAt': predecessorSettledAt!.toIso8601String(),
        'expiresAt': null,
      };

  Map<String, dynamic> _record() => {
        ..._roster(),
        'apkamPublicKey': apkamPublicKey,
        'encryptedAPKAMSymmetricKey': null,
        if (metadata != null) 'metadata': metadata,
      };
}

/// A value an atSign stores, with the metadata it was stored with.
class FakeRecord {
  FakeRecord(this.value, this.metadata);

  String value;
  final Map<String, dynamic> metadata;

  bool get isActive {
    final now = DateTime.now().toUtc();
    final availableAt = _parse(metadata['availableAt']);
    final expiresAt = _parse(metadata['expiresAt']);
    return !(availableAt != null && availableAt.isAfter(now)) &&
        !(expiresAt != null && expiresAt.isBefore(now));
  }
}

/// A notification as a recipient's atServer holds it.
class FakeNotification {
  FakeNotification({
    required this.id,
    required this.from,
    required this.to,
    required this.key,
    required this.value,
    required this.operation,
    required this.messageType,
    required this.isEncrypted,
    required this.metadata,
    this.ttr,
    this.ccd,
  }) : epochMillis = DateTime.now().millisecondsSinceEpoch;

  final String id;
  final String from;
  final String to;
  final String key;
  final String? value;
  final String operation;
  final String messageType;
  final bool isEncrypted;
  final Map<String, dynamic>? metadata;
  final int? ttr;
  final bool? ccd;
  final int epochMillis;

  String toJson() => jsonEncode({
        'id': id,
        'from': from,
        'to': to,
        'key': key,
        'value': value,
        'operation': operation,
        'epochMillis': epochMillis,
        'messageType': 'MessageType.$messageType',
        'isEncrypted': isEncrypted,
        'metadata': metadata,
      });
}

/// One client connection to a [FakeAtSign]'s atServer.
class FakeConnection {
  FakeConnection._(this.atSign) {
    _socket = _FakeSocket(_receive);
    _socket.serverSends('@');
  }

  final FakeAtSign atSign;
  late final _FakeSocket _socket;

  /// Every command received, in order.
  final List<String> commands = [];

  /// The enrollment this connection authenticated as, once it has.
  FakeEnrollment? enrollment;

  String? _challenge;
  RegExp? _monitorRegex;
  final StringBuffer _pending = StringBuffer();
  Future<void> _handling = Future.value();

  bool get isAuthenticated => enrollment != null;

  bool get isClosed => _socket._destroyed;

  String get _prompt => isAuthenticated ? '${atSign.atSign}@' : '@';

  void _receive(String data) {
    _pending.write(data);
    var text = _pending.toString();
    _pending.clear();
    while (text.contains('\n')) {
      final line = text.substring(0, text.indexOf('\n')).trim();
      text = text.substring(text.indexOf('\n') + 1);
      if (line.isNotEmpty) _handling = _handling.then((_) => _handle(line));
    }
    _pending.write(text);
  }

  Future<void> _handle(String command) async {
    if (isClosed) return;
    commands.add(command);
    final enrollment = this.enrollment;
    if (enrollment != null && enrollment.status != 'approved') {
      _close();
      return;
    }
    try {
      await _dispatch(command);
    } on _VerbError catch (e) {
      e.plain
          ? _plainError(e.code, e.description)
          : _error(e.code, e.description);
    }
  }

  Future<void> _dispatch(String command) async {
    if (_match(VerbSyntax.from, command) case final p?) return _from(p);
    if (_match(VerbSyntax.pkam, command) case final p?) return _pkam(p);
    if (_match(VerbSyntax.noOp, command) case final p?) return _noop(p);
    if (_match(VerbSyntax.info, command) != null) return _info();
    if (!isAuthenticated) {
      throw _VerbError('AT0401', 'Command cannot be executed without auth');
    }
    if (_match(VerbSyntax.llookup, command) case final p?) {
      return _llookup(command, p);
    }
    if (_match(VerbSyntax.plookup, command) case final p?) return _plookup(p);
    if (_match(VerbSyntax.lookup, command) case final p?) return _lookup(p);
    if (_match(VerbSyntax.update, command) case final p?) return _update(p);
    if (_match(VerbSyntax.delete, command) case final p?) return _delete(p);
    if (_match(VerbSyntax.notifyStatus, command) case final p?) {
      return _notifyStatus(p);
    }
    if (_match(VerbSyntax.notify, command) case final p?) return _notify(p);
    if (_match(VerbSyntax.monitor, command) case final p?) return _monitor(p);
    if (_match(VerbSyntax.scan, command) case final p?) return _scan(command, p);
    if (_match(VerbSyntax.enroll, command) case final p?) {
      return _enroll(command, p);
    }
    atSign.server.unhandled.add(command);
    throw _VerbError('AT0003', 'fake atServer has no handler for: $command');
  }

  Map<String, String?>? _match(String syntax, String command) =>
      RegExp(syntax, caseSensitive: false).hasMatch(command)
          ? VerbUtil.getVerbParam(syntax, command)
          : null;

  void _from(Map<String, String?> params) {
    if (params['atSign']?.toAtsign() != atSign.atSign) {
      throw _VerbError('AT0008', 'Invalid atSign ${params['atSign']}');
    }
    _challenge = '_${Uuid().v4()}${atSign.atSign}:${Uuid().v4()}';
    _data(_challenge!);
  }

  Future<void> _pkam(Map<String, String?> params) async {
    final id = params['enrollmentId']?.trim().toLowerCase();
    final enrollment = atSign.enrollments[id];
    if (enrollment == null) {
      throw _VerbError('AT0028', 'enrollment_id: $id is expired or invalid',
          plain: true);
    }
    const codes = {
      'denied': 'AT0025',
      'pending': 'AT0026',
      'revoked': 'AT0027',
    };
    if (enrollment.status != 'approved') {
      throw _VerbError(codes[enrollment.status] ?? 'AT0028',
          'enrollment_id: $id is ${enrollment.status}',
          plain: true);
    }
    final challenge = _challenge;
    _challenge = null;
    final hashing = params['hashingAlgo'] == 'sha512'
        ? HashingAlgoType.sha512
        : HashingAlgoType.sha256;
    final verified = challenge != null &&
        await _verifies(
          enrollment,
          utf8.encode(challenge),
          base64Decode(params['signature']!),
          hashing,
        );
    if (!verified) {
      throw _VerbError('AT0401', 'Exception: pkam authentication failed');
    }
    _settlePredecessor(enrollment);
    this.enrollment = enrollment;
    _data('success');
  }

  Future<bool> _verifies(
    FakeEnrollment enrollment,
    Uint8List message,
    Uint8List signature,
    HashingAlgoType hashing,
  ) async {
    final publicKey = base64Decode(enrollment.apkamPublicKey);
    return switch (enrollment.signingAlgo) {
      'mldsa65' => MlDsa65PureDartAlgo.verifyBytesSync(
          message,
          signature: signature,
          publicKey: publicKey,
        ),
      _ => await RsaSignatureAlgo.rsa2048(hashing: hashing)
          .verifyBytes(message, signature: signature, publicKey: publicKey),
    };
  }

  void _settlePredecessor(FakeEnrollment enrollment) {
    final predecessor = enrollment.retrofitPredecessor;
    if (predecessor == null || enrollment.predecessorSettledAt != null) return;
    if (!predecessor._isRoot) {
      atSign.server.unhandled.add('superseding ${predecessor.id}');
      throw _VerbError('AT0003',
          'fake atServer does not model superseding a non-root predecessor');
    }
    enrollment.predecessorSettledAt = DateTime.now().toUtc();
  }

  Future<void> _noop(Map<String, String?> params) async {
    final delay = int.parse(params['delayMillis']!);
    if (delay > 5000) throw _VerbError('AT0022', 'delay too long');
    await Future.delayed(Duration(milliseconds: delay));
    _data('ok');
  }

  void _info() => _data(jsonEncode({
        'version': 'fake',
        'uptimeAsWords': '0 seconds',
      }));

  void _llookup(String command, Map<String, String?> params) {
    var key = '${params['atKey']}@${params['atSign']}';
    if (params['forAtSign'] case final forAtSign?) key = '@$forAtSign:$key';
    final isPublic = command.contains('public:');
    if (isPublic) key = 'public:$key';
    if (command.contains('cached:')) key = 'cached:$key';
    key = key.toLowerCase();
    if (!isPublic && !_authorized(key, write: false)) {
      throw _VerbError(
        'AT0009',
        'UnAuthorized client in request : Connection with enrollment ID'
            ' ${enrollment!.id} is not authorized to llookup key: $key',
      );
    }
    _answerLookup(params['operation'], key, atSign.recordAt(key));
  }

  void _plookup(Map<String, String?> params) {
    final owner = atSign.server._find('@${params['atSign']}');
    final key = 'public:${params['atKey']}@${params['atSign']}'.toLowerCase();
    _answerLookup(params['operation'], key, owner?.recordAt(key),
        missing: 'key not found : Exception: $key does not exist in keystore');
  }

  void _lookup(Map<String, String?> params) {
    final ownerAtSign = '@${params['atSign']}'.toAtsign();
    var key = '${params['atKey']}$ownerAtSign';
    if (!key.contains(':')) key = '${atSign.atSign}:$key';
    key = key.toLowerCase();
    if (!_authorized(key, write: false)) {
      throw _VerbError(
        'AT0009',
        'Connection with enrollment ID ${enrollment!.id} is not authorized to'
            ' lookup key: $key',
      );
    }
    final record = atSign.server._find(ownerAtSign)?.recordAt(key);
    if (ownerAtSign != atSign.atSign && record == null) return _data('null');
    _answerLookup(params['operation'], key, record);
  }

  void _answerLookup(
    String? operation,
    String key,
    FakeRecord? record, {
    String? missing,
  }) {
    if (record == null) {
      throw _VerbError(
        'AT0015',
        missing ?? 'key not found : $key does not exist in keystore',
      );
    }
    if (!record.isActive) return _data('null');
    final metaData = _withoutNulls(record.metadata);
    switch (operation) {
      case 'meta':
        _data(jsonEncode(metaData));
      case 'all':
        _data(jsonEncode({
          'key': key,
          'data': record.value,
          'metaData': metaData,
        }));
      default:
        _data(record.value);
    }
  }

  void _update(Map<String, String?> params) {
    if (params['json'] != null) {
      atSign.server.unhandled.add('update:json');
      throw _VerbError('AT0003', 'fake atServer has no handler for update:json');
    }
    final key = _storedKey(params);
    if (!_authorized(key, write: true)) {
      throw _VerbError(
        'AT0009',
        'UnAuthorized client in request : Connection with enrollment ID'
            ' ${enrollment!.id} is not authorized to update key: $key',
      );
    }
    final existing = atSign.recordAt(key);
    if (existing != null && existing.metadata['immutable'] == true) {
      throw _VerbError('AT0032', 'Immutable records may not be updated');
    }
    final metadata = _mergeMetadata(params, existing?.metadata);
    final record = FakeRecord(params['value']!, metadata);
    atSign._store(key, record);
    final commitId = atSign._commit(key);
    if (params['forAtSign'] case final forAtSign?
        when '@$forAtSign'.toAtsign() != atSign.atSign) {
      _send(
        to: '@$forAtSign',
        key: key,
        value: record.value,
        operation: 'update',
        messageType: 'key',
        isEncrypted: metadata['isEncrypted'] == true,
        metadata: _notificationMetadata(metadata),
      );
    }
    _data('$commitId');
  }

  void _delete(Map<String, String?> params) {
    final key = _storedKey(params);
    const protected = {'publickey', 'signing_publickey', 'signing_privatekey'};
    if (protected.contains(params['atKey']?.toLowerCase())) {
      throw _VerbError('AT0009', "Cannot delete protected key: '$key'");
    }
    if (!_authorized(key, write: true)) {
      throw _VerbError(
        'AT0009',
        'UnAuthorized client in request : Connection with enrollment ID'
            ' ${enrollment!.id} is not authorized to delete key: $key',
      );
    }
    atSign._keyStore.remove(key);
    final commitId = atSign._commit(key);
    if (params['forAtSign'] case final forAtSign?
        when '@$forAtSign'.toAtsign() != atSign.atSign) {
      _send(
        to: '@$forAtSign',
        key: key,
        value: null,
        operation: 'delete',
        messageType: 'key',
        isEncrypted: true,
        metadata: null,
      );
    }
    _data('$commitId');
  }

  String _storedKey(Map<String, String?> params) {
    if (params['atSign'] case final owner?
        when '@$owner'.toAtsign() != atSign.atSign) {
      throw _VerbError(
          'AT0016', 'Invalid key: sharedBy must be ${atSign.atSign}');
    }
    var key = '${params['atKey']}${atSign.atSign}';
    if (params['forAtSign'] case final forAtSign?) key = '@$forAtSign:$key';
    if (params['publicScope'] != null) key = 'public:$key';
    return key.toLowerCase();
  }

  Map<String, dynamic> _mergeMetadata(
    Map<String, String?> params,
    Map<String, dynamic>? existing,
  ) {
    final now = DateTime.now();
    final metadata = {...existing ?? atSign._newMetadata()}
      ..['updatedBy'] = atSign.atSign
      ..['updatedAt'] = _timestamp(now);
    for (final field in ['ttl', 'ttb', 'ttr']) {
      if (params[field] case final v?) metadata[field] = int.parse(v);
    }
    for (final field in ['ccd', 'isBinary', 'isEncrypted', 'immutable']) {
      if (params[field] case final v?) metadata[field] = v == 'true';
    }
    for (final field in [
      'dataSignature',
      'sharedKeyEnc',
      'pubKeyCS',
      'encoding',
      'encKeyName',
      'encAlgo',
      'ivNonce',
      'skeEncKeyName',
      'skeEncAlgo',
    ]) {
      if (params[field] case final v?) metadata[field] = v;
    }
    if (params['pubKeyHash'] case final hash?) {
      metadata['pubKeyHash'] = {
        'hash': hash,
        'hashingAlgo': params['hashingAlgo'],
      };
    }
    if (params['appMetadata'] case final encoded?) {
      metadata['appMetadata'] =
          jsonDecode(utf8.decode(base64Decode(encoded)));
    }
    if (metadata['ttl'] case final int ttl when ttl > 0) {
      metadata['expiresAt'] = _timestamp(now.add(Duration(milliseconds: ttl)));
    }
    if (metadata['ttb'] case final int ttb) {
      metadata['availableAt'] =
          _timestamp(now.add(Duration(milliseconds: ttb)));
    }
    if (metadata['ttr'] case final int ttr when ttr > 0) {
      metadata['refreshAt'] = _timestamp(now.add(Duration(seconds: ttr)));
    }
    return metadata;
  }

  void _notifyStatus(Map<String, String?> params) =>
      _data(atSign.sentStatus[params['notificationId']] ?? 'null');

  void _notify(Map<String, String?> params) {
    if (params['atSign'] case final owner?
        when '@$owner'.toAtsign() != atSign.atSign) {
      throw _VerbError(
        'AT0009',
        '@$owner is not authorized to send notification as ${atSign.atSign}',
      );
    }
    final atKey = params['atKey']!;
    final forAtSign = params['forAtSign'];
    final messageType = params['messageType'] ?? 'key';
    final String key;
    if (messageType == 'text') {
      key = '@$forAtSign:$atKey';
    } else if (atKey.startsWith('public')) {
      key = '$atKey${atSign.atSign}';
    } else {
      key = '@$forAtSign:$atKey${atSign.atSign}';
    }
    if (!_authorized(key.toLowerCase(), write: true)) {
      throw _VerbError(
        'AT0009',
        'UnAuthorized client in request : Connection with enrollment ID'
            ' ${enrollment!.id} is not authorized to notify key: $key',
      );
    }
    final operation = params['operation'] ?? 'update';
    final value = params['value'];
    final ttr = int.tryParse(params['ttr'] ?? '');
    final keepsTtr = (operation == 'update' && ttr != null && value != null) ||
        (operation == 'delete' && ttr != null);
    final ttln = int.tryParse(params['ttln'] ?? '') ?? 0;
    final pubKeyHash = params['pubKeyHash'];
    final appMetadata = params['appMetadata'];
    final id = params['id'] ?? Uuid().v4();
    final bool isEncrypted;
    if (atKey.startsWith('public')) {
      isEncrypted = false;
    } else if (messageType == 'text') {
      isEncrypted = params['isEncrypted'] == 'true';
    } else {
      isEncrypted = params['isEncrypted'] != 'false';
    }
    _send(
      id: id,
      to: '@$forAtSign',
      key: key,
      value: value,
      operation: operation,
      messageType: messageType,
      isEncrypted: isEncrypted,
      ttr: keepsTtr ? ttr : null,
      ccd: keepsTtr ? params['ccd'] == 'true' : null,
      metadata: {
        'ttr': keepsTtr ? ttr : null,
        'ttl': int.tryParse(params['ttl'] ?? '') ?? 0,
        'ttb': int.tryParse(params['ttb'] ?? '') ?? 0,
        'sharedKeyEnc': params['sharedKeyEnc'],
        'pubKeyCS': params['pubKeyCS'],
        'dataSignature': null,
        'encKeyName': params['encKeyName'],
        'encAlgo': params['encAlgo'],
        'ivNonce': params['ivNonce'],
        'skeEncKeyName': params['skeEncKeyName'],
        'skeEncAlgo': params['skeEncAlgo'],
        'availableAt': 'null',
        'expiresAt': _timestamp(DateTime.now().add(
          Duration(milliseconds: ttln > 0 ? ttln : 15 * 60 * 1000),
        )),
        'pubKeyHash': pubKeyHash == null
            ? null
            : jsonEncode({
                'hash': pubKeyHash,
                'hashingAlgo': params['hashingAlgo'],
              }),
        'appMetadata': appMetadata == null
            ? null
            : jsonDecode(utf8.decode(base64Decode(appMetadata))),
      },
    );
    _data(id);
  }

  /// Delivers a notification from this connection's atSign to [to]'s
  /// atServer, recording whether it arrived.
  void _send({
    String? id,
    required String to,
    required String key,
    required String? value,
    required String operation,
    required String messageType,
    required bool isEncrypted,
    required Map<String, dynamic>? metadata,
    int? ttr,
    bool? ccd,
  }) {
    final notificationId = id ?? Uuid().v4();
    final recipient = atSign.server._find(to);
    atSign.sentStatus[notificationId] =
        recipient == null ? 'errored' : 'delivered';
    recipient?._receive(FakeNotification(
      id: notificationId,
      from: atSign.atSign,
      to: to.toAtsign(),
      key: key,
      value: value,
      operation: operation,
      messageType: messageType,
      isEncrypted: isEncrypted,
      metadata: metadata,
      ttr: ttr,
      ccd: ccd,
    ));
  }

  Map<String, dynamic> _notificationMetadata(Map<String, dynamic> stored) => {
        'ttr': stored['ttr'],
        'ttl': stored['ttl'] ?? 0,
        'ttb': stored['ttb'] ?? 0,
        'sharedKeyEnc': stored['sharedKeyEnc'],
        'pubKeyCS': stored['pubKeyCS'],
        'dataSignature': null,
        'encKeyName': stored['encKeyName'],
        'encAlgo': stored['encAlgo'],
        'ivNonce': stored['ivNonce'],
        'skeEncKeyName': stored['skeEncKeyName'],
        'skeEncAlgo': stored['skeEncAlgo'],
        'availableAt': '${stored['availableAt']}',
        'expiresAt': '${stored['expiresAt']}',
        'pubKeyHash': stored['pubKeyHash'] == null
            ? null
            : jsonEncode(stored['pubKeyHash']),
        'appMetadata': stored['appMetadata'],
      };

  void _monitor(Map<String, String?> params) {
    _monitorRegex = RegExp(params['regex'] ?? '.*');
    final since = int.tryParse(params['epochMillis'] ?? '');
    if (!atSign._monitors.contains(this)) atSign._monitors.add(this);
    if (since != null) {
      for (final n in atSign.received.where((n) => n.epochMillis > since)) {
        _deliver(n);
      }
    }
  }

  void _deliver(FakeNotification notification) {
    final regex = _monitorRegex;
    if (regex == null || isClosed) return;
    if (!_authorized(notification.key.toLowerCase(), write: false)) return;
    if (!notification.key.contains(regex) &&
        !notification.from.replaceFirst('@', '').contains(regex)) {
      return;
    }
    _socket.serverSends('notification: ${notification.toJson()}\n');
  }

  void _enroll(String command, Map<String, String?> params) {
    final Map<String, dynamic> body =
        jsonDecode(params['enrollParams'] ?? '{}');
    final namespace = params['listNamespace'] ?? '';
    switch (params['operation']) {
      case 'fetch':
        return _enrollFetch(body);
      case 'request':
        return _enrollRequest(body);
      case 'update':
        return _enrollUpdate(command, body);
      case 'list':
        return _enrollList(body);
      case 'listns':
        _requireNamespaceAccess(namespace, 'listns');
        return _data(jsonEncode([
          for (final e in atSign.enrollments.values)
            if (e.status == 'approved' && _accessFor(e, namespace) != null)
              {
                'enrollmentId': e.id,
                'access': _accessFor(e, namespace),
                'apkamPubKey': e.apkamPublicKey,
                'metadata': e.metadata,
              },
        ]));
      case 'infons':
        _requireNamespaceAccess(namespace, 'infons');
        final revoked = [
          for (final e in atSign.enrollments.values)
            if (e.revokedAt != null && _accessFor(e, namespace) != null)
              e.revokedAt!,
        ]..sort();
        return _data(jsonEncode(
            {'lastRevokedAt': revoked.lastOrNull?.toIso8601String()}));
    }
    atSign.server.unhandled.add(command);
    throw _VerbError('AT0003', 'fake atServer has no handler for: $command');
  }

  void _enrollFetch(Map<String, dynamic> body) {
    final id = (body['enrollmentId'] as String?)?.trim().toLowerCase();
    final target = atSign.enrollments[id];
    if (target == null) {
      throw _VerbError(
        'AT0015',
        'key not found : $id.new.enrollments.__manage${atSign.atSign}'
            ' does not exist in keystore',
      );
    }
    if (target != enrollment && enrollment!.namespaces['__manage'] == null) {
      throw _VerbError(
        'AT0009',
        'The approving enrollment does not have access to "__manage"'
            ' namespace',
      );
    }
    _data(jsonEncode({
      'appName': target.appName,
      'deviceName': target.deviceName,
      'namespace': target.namespaces,
      'encryptedAPKAMSymmetricKey': null,
      'status': target.status,
      'expiresAt': null,
      'metadata': target.metadata,
    }));
  }

  /// A connection's own enrollment asking to be replaced by one with a
  /// stronger key, which the atServer approves at once.
  void _enrollRequest(Map<String, dynamic> body) {
    final predecessor = enrollment!;
    final apkamPublicKey = body['apkamPublicKey'] as String?;
    if (body['appName'] == null ||
        body['deviceName'] == null ||
        apkamPublicKey == null) {
      throw _VerbError('AT0022',
          'appName, deviceName and apkamPublicKey are mandatory');
    }
    if (body['apsk'] != null && body['apskLegacy'] != null) {
      throw _VerbError('AT0022', 'apsk and apskLegacy are exclusive');
    }
    if (atSign.enrollments.values
        .any((e) => e.apkamPublicKey == apkamPublicKey)) {
      throw _VerbError(
          'AT0032', 'apkamPublicKey is held by another enrollment');
    }
    final requested = body['namespaces'] as Map<String, dynamic>?;
    final String? refusal = switch (predecessor) {
      _ when predecessor.status != 'approved' => 'is not approved',
      _ when predecessor.namespaces.isEmpty => 'has no namespaces',
      _ when predecessor.retrofitPredecessor != null =>
        'is itself a replacement',
      _ when !predecessor._isRoot &&
              atSign.enrollments.values.any((e) =>
                  e.retrofitPredecessor == predecessor &&
                  e.predecessorSettledAt != null) =>
        'has already been replaced',
      _ when requested != null &&
              !(requested.length == predecessor.namespaces.length &&
                  requested.entries.every(
                      (r) => predecessor.namespaces[r.key] == r.value)) =>
        'grants differ from those requested',
      _ => null,
    };
    if (refusal != null) {
      throw _VerbError(
          'AT0009', 'Enrollment ${predecessor.id} $refusal');
    }
    final successor = FakeEnrollment._(
      atSign,
      Uuid().v4(),
      appName: body['appName'],
      deviceName: body['deviceName'],
      namespaces: Map.of(predecessor.namespaces),
      apkamPublicKey: apkamPublicKey,
      signingAlgo: body['signingAlgo'] ?? 'rsa2048',
      retrofitPredecessor: predecessor,
      metadata: body['metadata'],
    );
    atSign.enrollments[successor.id] = successor;
    _publishApsk(successor, body);
    _data(jsonEncode({'enrollmentId': successor.id, 'status': 'approved'}));
  }

  void _publishApsk(FakeEnrollment e, Map<String, dynamic> body) {
    final value = body['apskLegacy'] ??
        (body['apsk'] == null ? null : jsonEncode(body['apsk']));
    if (value == null) return;
    atSign._store('public:_apsk.${e.id}.a.__e${atSign.atSign}',
        FakeRecord(value, atSign._newMetadata()));
  }

  void _enrollUpdate(String command, Map<String, dynamic> body) {
    final id = (body['enrollmentId'] as String?)?.trim().toLowerCase();
    final self = enrollment!;
    if (id != self.id) {
      throw _VerbError(
          'AT0011', 'enroll:update may change only the caller\'s enrollment');
    }
    if (self.status != 'approved') {
      throw _VerbError('AT0011', 'Enrollment $id is not approved');
    }
    if (body['namespaces'] != null) {
      throw _VerbError('AT0022', 'enroll:update cannot change namespaces');
    }
    if (body['apkamPublicKey'] != null || body['signingAlgo'] != null) {
      atSign.server.unhandled.add(command);
      throw _VerbError('AT0003',
          'fake atServer does not model changing an enrollment\'s key');
    }
    final metadata = body['metadata'] as Map<String, dynamic>?;
    if (metadata == null &&
        body['apsk'] == null &&
        body['apskLegacy'] == null) {
      throw _VerbError('AT0022', 'enroll:update has nothing to update');
    }
    if (metadata != null) self.metadata = {...?self.metadata, ...metadata};
    _publishApsk(self, body);
    _data(jsonEncode({'enrollmentId': self.id, 'status': 'approved'}));
  }

  void _enrollList(Map<String, dynamic> body) {
    final caller = enrollment!;
    final manages = caller.namespaces.containsKey('__manage');
    final statuses =
        (body['enrollmentStatusFilter'] as List?)?.cast<String>();
    final listed = manages
        ? atSign.enrollments.values
            .where((e) => statuses == null || statuses.contains(e.status))
        : [caller];
    final full = !manages || caller.namespaces['__manage']!.contains('w');
    _data(jsonEncode({
      for (final e in listed) e._recordKey: full ? e._record() : e._roster(),
    }));
  }

  void _requireNamespaceAccess(String namespace, String operation) {
    final caller = enrollment!;
    if (namespace.isEmpty) {
      throw _VerbError(
          'AT0022', 'namespace is required for enroll:$operation');
    }
    if (caller.status != 'approved') {
      throw _VerbError('AT0009', 'Caller enrollment is not in approved state');
    }
    if (_accessFor(caller, namespace) == null ||
        (namespace == '__manage' &&
            !caller.namespaces.containsKey('__manage'))) {
      throw _VerbError('AT0009',
          'Caller enrollment is not authorised for namespace "$namespace"');
    }
  }

  /// The access [e] holds over [namespace]: an exact or parent-segment grant,
  /// else its `*` grant.
  String? _accessFor(FakeEnrollment e, String namespace) {
    for (final MapEntry(key: ns, value: access) in e.namespaces.entries) {
      if (ns == '*') continue;
      if (ns == namespace || namespace.endsWith('.$ns')) return access;
    }
    return e.namespaces['*'];
  }

  void _scan(String command, Map<String, String?> params) {
    final forAtSign = params['forAtSign'];
    if (params['commitLog'] != null ||
        params['page'] != null ||
        (forAtSign != null && forAtSign.toAtsign() != atSign.atSign)) {
      atSign.server.unhandled.add(command);
      throw _VerbError('AT0003', 'fake atServer has no handler for: $command');
    }
    final regex = params['regex'] == null ? null : RegExp(params['regex']!);
    final showHidden = params['showhidden'] == 'true';
    final caller = enrollment!;
    bool hidden(String key) =>
        !(showHidden && (key.startsWith('public:__') || key.startsWith('_'))) &&
        (key.startsWith('private:') ||
            key.startsWith('privatekey:') ||
            key.startsWith('public:_') ||
            key.startsWith('_'));
    bool visible(String key) {
      if (key.startsWith('public:')) return true;
      if (caller.namespaces.isEmpty || caller.status != 'approved') {
        return false;
      }
      if (caller.namespaces.containsKey('*')) {
        return !_isForeignReserved(key, caller);
      }
      return key.contains('.') && _authorized(key, write: false);
    }

    _data(jsonEncode([
      for (final MapEntry(:key, value: record) in atSign._keyStore.entries)
        if (record.isActive &&
            (regex == null || regex.hasMatch(key)) &&
            !hidden(key) &&
            visible(key))
          key,
    ]));
  }

  bool _isForeignReserved(String key, FakeEnrollment caller) {
    final m = RegExp(r'(?:^|[.:])([^.:]+)\.[ard]\.__e@').firstMatch(key);
    return m != null && m.group(1) != caller.id;
  }


  /// Whether this connection's enrollment may read or write [key].
  bool _authorized(String key, {required bool write}) {
    final enrollment = this.enrollment!;
    if (enrollment.status != 'approved') return false;
    final owner = atSign.atSign;
    final body = key.substring(0, key.lastIndexOf('@'));
    final name =
        body.contains(':') ? body.substring(body.lastIndexOf(':') + 1) : body;
    final reserved =
        RegExp(r'^(?:[^.]+\.)?([^.]+)\.[ard]\.__e$').firstMatch(name);
    if (reserved != null && reserved.group(1) != enrollment.id) {
      return !write && key.startsWith('public:');
    }
    bool writesAnywhere() => enrollment.namespaces.values.contains('rw');
    bool isRoot() =>
        enrollment.namespaces['*'] == 'rw' &&
        enrollment.namespaces['__manage'] == 'rw';
    if (RegExp('^@[^:]+:shared_key$owner\$').hasMatch(key) ||
        RegExp('^shared_key\\.[^.@]+$owner\$').hasMatch(key)) {
      return write ? writesAnywhere() : true;
    }
    if (key == 'public:publickey$owner' ||
        key == 'public:signing_publickey$owner') {
      return write ? isRoot() : true;
    }
    if (!name.contains('.')) return writesAnywhere() || !write;
    final namespace = name.substring(name.indexOf('.') + 1);
    final grants = {
      '__atserver': 'r',
      ...enrollment.namespaces,
      '${enrollment.id}.a.__e': 'rw',
    };
    String? access;
    for (final MapEntry(key: granted, value: level) in grants.entries) {
      if (granted == '*' || granted == '__manage') continue;
      if ('.$namespace'.endsWith('.$granted')) {
        access = level;
        break;
      }
    }
    if (access == null &&
        namespace != '__manage' &&
        !namespace.endsWith('.__manage')) {
      access = grants['*'];
    }
    if (access == null) return false;
    return write ? access == 'rw' : access.contains('r');
  }

  void _close() => _socket.destroy();

  void _data(String value) => _socket.serverSends('data:$value\n$_prompt');

  void _error(String code, String description) => _socket.serverSends(
        'error:${jsonEncode({
          'errorCode': code,
          'errorDescription': description,
        })}\n$_prompt',
      );

  void _plainError(String code, String description) =>
      _socket.serverSends('error:$code:$description\n$_prompt');
}

class _VerbError implements Exception {
  _VerbError(this.code, this.description, {this.plain = false});

  final String code;
  final String description;
  final bool plain;
}

String _timestamp(DateTime time) => time.toUtc().toString();

DateTime? _parse(Object? timestamp) =>
    timestamp is String ? DateTime.tryParse(timestamp) : null;

Map<String, dynamic> _withoutNulls(Map<String, dynamic> map) => {
      for (final MapEntry(:key, :value) in map.entries)
        if (value != null)
          key: value is Map<String, dynamic> ? _withoutNulls(value) : value,
    };

/// A [SecureSocket] a [FakeConnection] drives, over a real single-subscription
/// stream so pause, resume, done and error are real events.
class _FakeSocket implements SecureSocket {
  _FakeSocket(this._onWrite);

  final void Function(String data) _onWrite;
  final StreamController<Uint8List> _inbound = StreamController<Uint8List>();
  bool _destroyed = false;

  void serverSends(String data) {
    if (_destroyed || _inbound.isClosed) return;
    _inbound.add(Uint8List.fromList(utf8.encode(data)));
  }

  @override
  StreamSubscription<Uint8List> listen(
    void Function(Uint8List event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) =>
      _inbound.stream.listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError,
      );

  @override
  void write(Object? object) => _record('$object');

  @override
  void writeln([Object? object = '']) => _record('$object\n');

  @override
  void add(List<int> data) => _record(utf8.decode(data));

  void _record(String data) {
    if (_destroyed) {
      throw SocketException('write to a socket the client destroyed');
    }
    // NOTE delivered on a later turn, as a real socket would, so a handler
    // can't run inside the client's write call.
    scheduleMicrotask(() => _onWrite(data));
  }

  @override
  Future<void> flush() async {}

  @override
  void destroy() {
    _destroyed = true;
    if (!_inbound.isClosed) _inbound.close();
  }

  @override
  Future<void> close() async => destroy();

  @override
  Future get done => _inbound.done;

  @override
  bool setOption(SocketOption option, bool enabled) => true;

  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 6464;

  @override
  InternetAddress get address => InternetAddress.loopbackIPv4;

  @override
  int get port => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
        '_FakeSocket does not implement ${invocation.memberName}',
      );
}

class _FakeSocketFactory extends AtLookupSecureSocketFactory {
  _FakeSocketFactory(this._server);

  final FakeAtServer _server;

  @override
  Future<SecureSocket> createSocket(
    String host,
    String port,
    SecureSocketConfig socketConfig, {
    Duration? timeout,
  }) async =>
      _server._connect(host, port)._socket;
}

class _FakeAddressFinder extends SecondaryAddressFinder {
  _FakeAddressFinder(this._server);

  final FakeAtServer _server;

  @override
  Future<SecondaryAddress> findSecondary(
    String atSign, {
    Duration? timeout,
  }) async =>
      SecondaryAddress(FakeAtServer._host, _server[atSign].port);
}

class _FakeServiceFactory extends ServiceFactoryWithNoOpSyncService {
  _FakeServiceFactory(this._server);

  final FakeAtServer _server;

  @override
  Future<NotificationService> notificationService(
    AtClient atClient,
    AtClientManager atClientManager, {
    SecondaryAddressFinder? secondaryAddressFinder,
  }) =>
      super.notificationService(
        atClient,
        atClientManager,
        secondaryAddressFinder: _server.addressFinder,
      );
}
