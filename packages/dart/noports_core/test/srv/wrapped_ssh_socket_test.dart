import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srv/srv_impl.dart' show WrappedSSHSocket;
import 'package:socket_connector/socket_connector.dart' show DataTransformer;
import 'package:test/test.dart';

class _MockIOSink extends Mock implements IOSink {}

void main() {
  group('WrappedSSHSocket teardown', () {
    // Regression coverage for PR #2904 review: close()/destroy() closed only
    // the underlying socket, never the StreamController feeding [encrypter].
    // An identity encrypter is enough to prove the controller gets closed —
    // it doesn't need a real cipher to observe the leak or its fix.
    DataTransformer identity() => (Stream<List<int>> stream) => stream;

    test('close() closes the plaintext sink feeding the encrypter', () async {
      final socket = WrappedSSHSocket(
        const Stream<Uint8List>.empty(),
        _MockIOSink(),
        identity(),
        null,
        onClose: () async {},
        onDestroy: () {},
      );

      await socket.close();

      expect(
        () => socket.sink.add(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('destroy() closes the plaintext sink feeding the encrypter',
        () async {
      final socket = WrappedSSHSocket(
        const Stream<Uint8List>.empty(),
        _MockIOSink(),
        identity(),
        null,
        onClose: () async {},
        onDestroy: () {},
      );

      socket.destroy();
      // destroy()'s sink close is fire-and-forget, matching destroy()'s own
      // synchronous, no-guarantees contract; give it one microtask turn.
      await Future<void>.delayed(Duration.zero);

      expect(
        () => socket.sink.add(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<StateError>()),
      );
    });

    test('with no encrypter, sink is the underlying sink and close() never '
        'closes it directly (only onClose may)', () async {
      final underlyingSink = _MockIOSink();
      final socket = WrappedSSHSocket(
        const Stream<Uint8List>.empty(),
        underlyingSink,
        null,
        null,
        onClose: () async {},
        onDestroy: () {},
      );

      expect(socket.sink, same(underlyingSink));
      await socket.close();

      verifyNever(() => underlyingSink.close());
    });
  });
}
