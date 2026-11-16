import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sends [eventName] to window_manager the way its native side does, so every
/// `WindowListener` hears it.
Future<void> sendWindowEvent(String eventName) {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'window_manager',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('onEvent', <String, Object?>{'eventName': eventName}),
        ),
        (ByteData? _) {},
      );
}
