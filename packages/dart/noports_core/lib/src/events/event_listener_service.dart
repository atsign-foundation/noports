import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:noports_core/events.dart';

class EventListenerService with EventListener, AtClientBindings {
  @override
  final AtClient atClient;
  @override
  final AtSignLogger logger = AtSignLogger(' EventListenerService ');

  EventListenerService({required this.atClient});

  void listen(EventLoggingConfig elc, Function f) {
    subscribe(
      regex: elc.topicListenRegex,
      shouldDecrypt: true,
    ).listen((AtNotification n) {
      f(n);
    });
  }
}
