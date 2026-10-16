import 'package:at_client/at_client.dart';

/// Thrown by `NPAImpl.run()` when it can't fetch the event logging config
/// from its event logging Atsign.
class EventLoggingConfigException implements Exception {
  /// The event logging Atsign the config was fetched from.
  final Atsign eventLoggingAtsign;

  /// What the config fetch threw.
  final Object cause;

  EventLoggingConfigException(this.eventLoggingAtsign, this.cause);

  /// True only when the config key isn't there for this policy Atsign.
  bool get notShared => cause is AtKeyNotFoundException;

  @override
  String toString() => notShared
      ? '$eventLoggingAtsign has not yet shared its event logging config'
            ' with this policy Atsign'
      : 'Could not fetch the event logging config from $eventLoggingAtsign:'
            ' ${cause is AtException ? (cause as AtException).message : cause}';
}
