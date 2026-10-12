import 'package:at_client_flutter/at_client_flutter.dart';

/// Converts text a user typed as an atSign.
extension AtsignText on String {
  /// This text as an atSign, or null when at_commons refuses it.
  Atsign? toAtsignOrNull() {
    try {
      return toAtsign();
    } on InvalidAtSignException {
      return null;
    }
  }

  /// Whether at_commons refuses this text as an atSign for being too long.
  bool get isTooLongForAtsign {
    try {
      toAtsign();
    } on InvalidAtSignException catch (e) {
      return e.message == AtMessage.tooLong.text;
    }
    return false;
  }
}
