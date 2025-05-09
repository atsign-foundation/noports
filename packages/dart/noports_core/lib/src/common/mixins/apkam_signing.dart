import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';

/// We're going to use our (A)PKAM private key to sign our authentication
/// message to the relay. Our public key needs to be in a standard place
/// associated with this enrollment; the relay will only accept signatures
/// when signed by a public key in this standard place.
/// A future atServer release will ensure that records placed in this
/// standard place will
/// (1) be removed when an enrollment expires or is deleted, and
/// (2) return a KeyNotFoundException if an enrollment is revoked (but
/// not yet deleted).
///
/// Let's check if our APKAM public key is there already and put it there
/// if not. We will also make it immutable to prevent accidents.
///
/// Key will be placed at <some key id>.<enrollment id>.__wa@alice where
/// "__wa" means "while active". Note that atServer will also be enhanced
/// to enforce the rule that if you are creating records in the
/// <enrollment id>.__wa namespace, then you are authenticated as that
/// same enrollment.
mixin ApkamSigning {
  AtClient get atClient;

  AtSignLogger get logger;

  String get enrollmentId {
    String id =
        atClient.getRemoteSecondary()!.atLookUp.enrollmentId ?? 'primary';
    if (id == 'primary') {
      logger.warning('No enrollmentID ... using "primary"');
    }
    return id;
  }

  /// the uri (e.g. `public:<id>.<enrollment_id>.__wa@atsign`) of the
  /// [publicSigningKey]
  String get publicSigningKeyUri {
    return 'public:dsk.$enrollmentId.__wa${atClient.getCurrentAtSign()}';
  }

  /// the public key which can be used to verify signatures made using
  /// [privateSigningKey]
  String get publicSigningKey {
    return atClient.atChops!.atChopsKeys.atPkamKeyPair!.atPublicKey.publicKey;
  }

  /// the private key used to sign things this application sends
  String get privateSigningKey {
    return atClient.atChops!.atChopsKeys.atPkamKeyPair!.atPrivateKey.privateKey;
  }

}
