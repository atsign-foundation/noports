import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/common/default_args.dart';
import 'package:noports_core/src/sshnp/models/sshnp_params.dart';

/// The namespace a [device] daemon publishes its namespace key at, which a
/// client checks to tell whether that daemon is post-quantum capable.
String deviceNamespace(String device) => '$device.${DefaultArgs.namespace}';

/// How long an answer from [schemeFor] is used before it is asked again.
const Duration _remembered = Duration(minutes: 10);

/// What [schemeFor] has found out, per client, so that one enrollment's
/// answer, which says whether it holds its own private, is never another's.
final Expando<Map<String, ({String scheme, DateTime at})>> _schemes = Expando();

/// The provider to send to [receiver] under, or null for this client's
/// default when its posture is not post-quantum.
///
/// Post-quantum only when [receiver] advertises a key at exactly [sealTo] and
/// this client holds the private of its own key at [own], which opens the
/// reply and covers the copy of the content key a sender keeps; legacy
/// otherwise, so a receiver that publishes no key is still reached. An answer
/// is reused by [atClient] for ten minutes; a failure to find out is not.
Future<String?> schemeFor(
  AtClient atClient, {
  required String receiver,
  required String sealTo,
  required String own,
  required AtSignLogger logger,
}) async {
  if (atClient.getPreferences()?.posture.configuresPqProviders != true) {
    return null;
  }
  final key = '$receiver $sealTo $own';
  final now = DateTime.now();
  final answers = _schemes[atClient] ??= {};
  final remembered = answers[key];
  if (remembered != null && now.difference(remembered.at) < _remembered) {
    return remembered.scheme;
  }
  try {
    // ignore: experimental_member_use
    final advertised = await PublishedNskeyKeyRing(
      atClient,
    ).publishedAdvertisement(receiver, sealTo);
    final String scheme;
    if (advertised == null) {
      logger.info('$receiver publishes no key for $sealTo, so it is sent legacy');
      scheme = legacyCryptoProviderId;
    } else if ((await atClient.ensureReachable(own)).holdsPrivate) {
      scheme = symmetricAesGcmCryptoProviderId;
    } else {
      logger.warning(
        'This client does not hold the private of its own $own key, so'
        ' $receiver is sent legacy and answers legacy',
      );
      scheme = legacyCryptoProviderId;
    }
    answers[key] = (scheme: scheme, at: now);
    return scheme;
  } catch (e) {
    logger.warning(
      'Could not tell whether $receiver accepts post-quantum for $sealTo, so'
      ' it is sent legacy: $e',
    );
    return legacyCryptoProviderId;
  }
}

/// The provider to send [params]' request to its daemon under: post-quantum
/// when the daemon publishes its device's key, as [schemeFor] decides.
Future<String?> requestProviderId(
  AtClient atClient,
  ClientParams params,
  AtSignLogger logger,
) => schemeFor(
  atClient,
  receiver: params.sshnpdAtSign,
  sealTo: deviceNamespace(params.device),
  own: DefaultArgs.namespace,
  logger: logger,
);
