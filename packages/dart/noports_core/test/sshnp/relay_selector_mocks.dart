import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/relay_selector.dart';

class StubbedRelaySelector extends RelaySelector {
  final Future<NotificationResult> Function(
    AtKey,
    String, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,
    int maxTries,
  })
  _notify;
  final Stream<AtNotification> Function({String? regex, bool shouldDecrypt})
  _subscribe;

  StubbedRelaySelector({
    required super.atClient,
    required super.clientAtSign,
    required super.sshnpdAtSign,
    required super.device,
    required super.rootDomain,
    required Future<NotificationResult> Function(
      AtKey,
      String, {
      required bool checkForFinalDeliveryStatus,
      required bool waitForFinalDeliveryStatus,
      required Duration ttln,
      int maxTries,
    })
    notify,
    required Stream<AtNotification> Function({String? regex, bool shouldDecrypt})
    subscribe,
  }) : _notify = notify,
       _subscribe = subscribe;

  @override
  Future<NotificationResult> notify(
    AtKey atKey,
    String value, {
    required bool checkForFinalDeliveryStatus,
    required bool waitForFinalDeliveryStatus,
    required Duration ttln,
    int maxTries = 3,
  }) async {
    return _notify(
      atKey,
      value,
      checkForFinalDeliveryStatus: checkForFinalDeliveryStatus,
      waitForFinalDeliveryStatus: waitForFinalDeliveryStatus,
      ttln: ttln,
      maxTries: maxTries,
    );
  }

  @override
  Stream<AtNotification> subscribe({
    String? regex,
    bool shouldDecrypt = false,
  }) {
    return _subscribe(regex: regex, shouldDecrypt: shouldDecrypt);
  }
}
