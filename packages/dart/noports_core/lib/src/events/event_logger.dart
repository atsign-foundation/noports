import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';
import 'package:noports_core/src/events/event_models.dart';

mixin NPEventLogger {
  AtClient get atClient;

  AtSignLogger get logger;

  Future<void> log(Atsign loggingAtsign, NPEvent event) async {
    logger.shout('Sending log to $loggingAtsign: ${event.toJson().toString()}');
    await atClient.notificationService.notify(
      NotificationParams.forUpdate(
        AtKey.fromString(
          '$loggingAtsign:__logging__.sshnp${atClient.getCurrentAtSign()!}',
        )..metadata.namespaceAware=false,
        value: jsonEncode(event.toJson()),
      ),
      waitForFinalDeliveryStatus: false,
      checkForFinalDeliveryStatus: false,
    );
  }
}
