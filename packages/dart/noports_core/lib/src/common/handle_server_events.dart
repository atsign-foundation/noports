import 'dart:convert';

import 'package:at_client/at_client.dart';
import 'package:at_utils/at_logger.dart';

AtSignLogger logger = AtSignLogger(' handle_server_events ');

handlePublicKeyChangedEvent(AtClient atClient, Atsign atSign) {
  String topic = '.*\\.events\\.__atserver$atSign';

  atClient.notificationService
      .subscribe(regex: topic, shouldDecrypt: true)
      .listen((AtNotification n) async {
    final dynamic ej;
    try {
      ej = jsonDecode(n.value!);
    } catch (e) {
      logger.shout(
        'Caught exception $e'
        ' while handling server event notification $n',
      );
      return;
    }

    final category = ej['category'];
    if (category == null) {
      logger.shout('No "category" in server event $ej');
      return;
    }
    final name = ej['name'];
    if (name == null) {
      logger.shout('No "name" in server event $ej');
      return;
    }

    try {
      switch (category) {
        case AtServerEvent.atProtocolCategory:
          final name = ej['name'];
          switch (name) {
            case AtServerEvent.atSignPKChangedEventName:
              logger.shout('HANDLING public key change event: $ej');
              AtSignPKChangedEvent e = AtSignPKChangedEvent.fromJson(ej);
              List<String> keysToRemove = [
                'shared_key.${e.atSign.substring(1)}$atSign',
                '${e.atSign}:shared_key$atSign',
                'cached:public:publickey${e.atSign}',
              ];

              for (final k in keysToRemove) {
                logger.shout('Removing $k from local storage');
                await atClient.getLocalSecondary()!.keyStore!.remove(
                      k,
                      skipCommit: true,
                    );
              }
              logger.shout('HANDLED OK');
              break;
            default:
              logger.shout(
                'Not handling server event'
                ' of category $category'
                ' with name $name',
              );
              break;
          }
          break;
        default:
          logger.shout(
            'Not handling server event'
            ' of category $category',
          );
          break;
      }
    } catch (e) {
      logger.shout(
        'Exception $e while handling server event notification $n',
      );
    }
  });
}
