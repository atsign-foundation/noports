import 'package:at_client/at_client.dart';
import 'package:at_client/at_client_mixins.dart';
import 'package:at_utils/at_logger.dart' show AtSignLogger;
import 'package:noports_core/events.dart';

class AtEventListenerService with AtClientBindings, AtEventListener {
  @override
  final AtClient atClient;
  @override
  final AtSignLogger logger = AtSignLogger(' AtEventListenerService ');

  AtEventListenerService({required this.atClient});
}
