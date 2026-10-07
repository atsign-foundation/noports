import 'dart:convert';

import 'package:at_auth/at_auth.dart'
    show ApskSigningKey, apskSigningKeys, publicKeyKidOfBase64;
import 'package:at_chops/at_chops.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:noports_core/src/common/session_crypto.dart';
import 'package:noports_core/src/common/validation_utils.dart'
    show signAndWrap;
import 'package:noports_core/src/srv/relay_authenticators.dart'
    show escrSigningKeyPair;

/// The request envelope field holding the payload's signature by the
/// sender's enrollment key, beside the atSign-wide `signature`.
const String enrollmentSignatureField = 'enrollmentSignature';

/// A signature that doesn't verify against the `_apsk` record it names.
class ApskSignatureException implements Exception {
  ApskSignatureException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The only shape a signing key URI may take: the `_apsk` record an
/// enrollment publishes, so the atSign read from it is the record's owner.
final RegExp signingKeyUriShape = RegExp(
  '^(public:)?_apsk\\.[A-Za-z0-9_-]+\\.'
  '${RegExp.escape(EnrollmentConstants.perEnrollmentApproved)}@[^@:\\s]+\$',
);

/// [uri] in the form an atServer stores it under, with the `public:` prefix,
/// so every spelling of one `_apsk` record compares equal.
String canonicalSigningKeyUri(String uri) =>
    'public:${uri.toLowerCase().replaceFirst(RegExp('^public:'), '')}';

/// Signs [data] with [privateKey] under [algorithm], as relay authentication
/// and request signatures do.
String signWithApskKey(
  String data, {
  required SigningAlgoType algorithm,
  required String privateKey,
}) =>
    switch (algorithm) {
      SigningAlgoType.mldsa65 => base64Encode(
          MlDsa65PureDartAlgo.signBytesSync(
            utf8.encode(data),
            secretKey: base64Decode(privateKey),
          ),
        ),
      SigningAlgoType.rsa2048 => rsaSignString(data, privateKey: privateKey),
      _ => throw ArgumentError.value(
          algorithm,
          'algorithm',
          'NoPorts signs with'
              ' ${escrSigningAlgorithms.map((a) => a.name).join(' or ')}',
        ),
    };

/// The keys [apsk], the value of the `_apsk` record [uri], offers for new
/// signatures under an algorithm NoPorts verifies. A value starting with `{`
/// is the JSON advertisement at_auth defines; anything else is one bare RSA
/// key.
List<ApskSigningKey> activeApskKeys(String uri, String apsk) {
  final value = apsk.trim();
  final List<ApskSigningKey> advertised;
  if (value.startsWith('{')) {
    final Object? decoded;
    try {
      decoded = jsonDecode(value);
    } on FormatException catch (e) {
      throw ApskSignatureException(
        '$uri holds an advertisement that is not JSON: ${e.message}',
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw ApskSignatureException(
        '$uri holds an advertisement that is not a JSON object',
      );
    }
    advertised = apskSigningKeys(decoded);
  } else {
    try {
      advertised = [
        ApskSigningKey.forPublicKey(alg: SigningAlgoType.rsa2048, pub: value),
      ];
    } on FormatException catch (e) {
      throw ApskSignatureException(
        '$uri holds a key that is not base64: ${e.message}',
      );
    }
  }
  final keys = [
    for (final k in advertised)
      if (k.offeredForNewOperations && escrSigningAlgorithms.contains(k.alg)) k,
  ];
  if (keys.isEmpty) {
    throw ApskSignatureException('$uri advertises no key NoPorts can verify');
  }
  return keys;
}

/// Verifies [signature], made over [signed] under [signingAlgo], with the key
/// [kid] names in [apsk], the value of the `_apsk` record [uri]. [signingAlgo]
/// must be the strongest algorithm the record offers; with no [kid], the
/// record must offer exactly one key under it.
///
/// Throws [ApskSignatureException] naming why the signature doesn't verify.
Future<void> verifyApskSignature({
  required String uri,
  required String apsk,
  required String signed,
  required String signature,
  required SigningAlgoType signingAlgo,
  required HashingAlgoType hashingAlgo,
  String? kid,
}) async {
  final advertised = activeApskKeys(uri, apsk);
  final required = SigningAlgoType.strongestOf(advertised.map((k) => k.alg))!;
  if (signingAlgo != required) {
    throw ApskSignatureException(
      'Signed with ${signingAlgo.name}, but $uri advertises ${required.name},'
      ' the strongest algorithm it offers',
    );
  }
  final candidates = advertised.where((k) => k.alg == required).toList();
  final key = kid == null
      ? (candidates.length == 1
          ? candidates.single
          : throw ApskSignatureException(
              'The signature names no key, and $uri advertises'
              ' ${candidates.length} ${required.name} keys',
            ))
      : candidates.where((k) => k.kid == kid).firstOrNull ??
          (throw ApskSignatureException(
            'The signature names key $kid, which $uri does not advertise',
          ));
  final bool verified;
  try {
    verified = switch (required) {
      SigningAlgoType.mldsa65 => MlDsa65PureDartAlgo.verifyBytesSync(
          utf8.encode(signed),
          signature: base64Decode(signature),
          publicKey: base64Decode(key.pub),
        ),
      _ => await rsaVerifyString(
          signed,
          signature: signature,
          publicKey: key.pub,
          hashing: hashingAlgo,
        ),
    };
  } on FormatException catch (e) {
    throw ApskSignatureException('The signature is not base64: ${e.message}');
  }
  if (!verified) {
    throw ApskSignatureException('Signatures did not match.');
  }
}

/// Where the `_apsk` record [uri] (canonical, as [canonicalSigningKeyUri]
/// gives it) was withdrawn to: `r.__e` when its enrollment was revoked or
/// superseded, `d.__e` when deleted or expired; null when neither holds it.
Future<String?> signingKeyWithdrawnTo(AtClient atClient, String uri) async {
  final match = RegExp(
    '^public:_apsk\\.([a-z0-9_-]+)'
    '\\.${RegExp.escape(EnrollmentConstants.perEnrollmentApproved)}'
    '(@[^@:\\s]+)\$',
  ).firstMatch(uri);
  if (match == null) return null;
  return withdrawnApskLocation(atClient, match.group(2)!, match.group(1)!);
}

/// [signer]'s enrollment signature over [payload]'s JSON, for
/// [enrollmentSignatureField]: the `_apsk` record it can be checked against
/// (`sk`), the key within it (`kid`), and the algorithms and signature.
/// Publishes that record first, if it isn't already, so the signature can be
/// verified. Null when [signer] holds no key it can sign with, or can't
/// publish it.
Future<Map<String, String>?> enrollmentSignatureOf(
  ApkamSigning signer,
  Map payload,
) async {
  final ({SigningAlgoType algorithm, String publicKey, String privateKey}) key;
  try {
    key = await escrSigningKeyPair(signer);
  } on AtClientException {
    return null;
  }
  try {
    await signer.publishPublicSigningKey();
  } on Exception catch (e) {
    signer.logger.warning(
      'Not signing with enrollment ${signer.enrollmentId}:'
      ' could not publish its signing key: $e',
    );
    return null;
  }
  return {
    'sk': signer.publicSigningKeyUri,
    'kid': publicKeyKidOfBase64(key.publicKey),
    'sa': key.algorithm.name,
    'ha': HashingAlgoType.sha256.name,
    's': signWithApskKey(
      jsonEncode(payload),
      algorithm: key.algorithm,
      privateKey: key.privateKey,
    ),
  };
}

/// [payload] in the envelope [signAndWrap] makes, signed by [signer]'s
/// enrollment key too when it holds one, as a request to a daemon.
Future<String> signAndWrapRequest(
  AtClient atClient,
  ApkamSigning signer,
  Map payload,
) async {
  final envelope = await signAndWrap(atClient, payload);
  final enrollmentSignature = await enrollmentSignatureOf(signer, payload);
  if (enrollmentSignature != null) {
    envelope[enrollmentSignatureField] = enrollmentSignature;
  }
  return jsonEncode(envelope);
}

/// Verifies the [enrollmentSignatureField] of [envelope], a request from
/// [requester], against the `_apsk` record it names, looked up with
/// [atClient]. Returns that record's canonical URI, or null when [envelope]
/// carries no such field.
///
/// Throws [ApskSignatureException] when the field is malformed, names a
/// record that isn't [requester]'s, or doesn't verify; a failed lookup of the
/// record throws whatever the lookup threw.
Future<String?> verifyEnrollmentSignature(
  AtClient atClient,
  String requester,
  Map envelope,
) async {
  final Object? field = envelope[enrollmentSignatureField];
  if (field == null) return null;
  if (field is! Map) {
    throw ApskSignatureException('$enrollmentSignatureField is not an object');
  }
  String text(String name) => field[name] is String
      ? field[name]
      : throw ApskSignatureException(
          '$enrollmentSignatureField has no string "$name"',
        );
  final uri = text('sk');
  if (!signingKeyUriShape.hasMatch(uri)) {
    throw ApskSignatureException(
      'Signing key ($uri) is not of the form public:_apsk.<enrollmentId>'
      '.${EnrollmentConstants.perEnrollmentApproved}@<atSign>',
    );
  }
  final signer = uri.substring(uri.lastIndexOf('@')).toLowerCase();
  if (signer != requester.toLowerCase()) {
    throw ApskSignatureException(
      'Signing key $uri belongs to $signer, not the requester $requester',
    );
  }
  final SigningAlgoType signingAlgo;
  final HashingAlgoType hashingAlgo;
  try {
    signingAlgo = SigningAlgoType.values.byName(text('sa'));
    hashingAlgo = HashingAlgoType.values.byName(text('ha'));
  } on ArgumentError {
    throw ApskSignatureException(
      '$enrollmentSignatureField names an algorithm NoPorts does not know',
    );
  }
  if (!escrSigningAlgorithms.contains(signingAlgo)) {
    throw ApskSignatureException(
      'Unsupported signing algorithm ${signingAlgo.name}',
    );
  }
  final kid = switch (field['kid']) {
    null => null,
    final String kid => kid,
    _ => throw ApskSignatureException(
        '$enrollmentSignatureField has a "kid" that is not a string',
      ),
  };
  final canonical = canonicalSigningKeyUri(uri);
  final apsk = (await atClient.get(
    AtKey.fromString(canonical),
    getRequestOptions: GetRequestOptions()..useRemoteAtServer = true,
  ))
      .value;
  if (apsk is! String) {
    throw ApskSignatureException('$canonical holds no signing key');
  }
  await verifyApskSignature(
    uri: canonical,
    apsk: apsk,
    signed: jsonEncode(envelope['payload']),
    signature: text('s'),
    signingAlgo: signingAlgo,
    hashingAlgo: hashingAlgo,
    kid: kid,
  );
  return canonical;
}
