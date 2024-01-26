import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:at_chops/at_chops.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/srvd/signature_verifying_socket_authenticator.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  late AtChops atChops;

  setUpAll(() {
    AtEncryptionKeyPair encryptionKeyPair =
        AtChopsUtil.generateAtEncryptionKeyPair(keySize: 2048);

    atChops = AtChopsImpl(AtChopsKeys.create(encryptionKeyPair, null));
  });
  test('SignatureVerifyingSocketAuthenticator signature verification success',
      () async {
    String rvdSessionNonce = DateTime.now().toIso8601String();
    Map payload = {'sessionId': Uuid().v4(), 'rvdNonce': rvdSessionNonce};

    late Function(Uint8List data) socketOnDataFn;
    MockSocket mockSocket = MockSocket();

    String signedEnvelope = signPayload(atChops, payload);
    SignatureAuthVerifier sa = SignatureAuthVerifier(
        atChops.atChopsKeys.atEncryptionKeyPair!.atPublicKey.publicKey,
        jsonEncode(payload), // We'll verify the signature against this
        rvdSessionNonce,
        'test_for_success');

    List<int> list = utf8.encode('$signedEnvelope\n');
    Uint8List data = Uint8List.fromList(list);

    when(() => mockSocket.listen(any(),
        onError: any(named: "onError"),
        onDone: any(named: "onDone"))).thenAnswer((Invocation invocation) {
      socketOnDataFn = invocation.positionalArguments[0];

      socketOnDataFn(data);

      return MockStreamSubscription<Uint8List>();
    });

    bool authenticated;
    Stream<Uint8List>? stream;

    (authenticated, stream) = await sa.authenticate(mockSocket);
    expect(authenticated, true);
    expect(stream, isNotNull);
  });

  test('SignatureVerifyingSocketAuthenticator signature verification failure',
      () async {
    String rvdSessionNonce = DateTime.now().toIso8601String();
    Map payload = {
      'sessionId': Uuid().v4().toString(),
      'rvdNonce': rvdSessionNonce
    };

    String signedEnvelope = signPayload(atChops, payload);
    SignatureAuthVerifier sa = SignatureAuthVerifier(
        atChops.atChopsKeys.atEncryptionKeyPair!.atPublicKey.publicKey,
        // using a different payload; signature verification will fail
        'some other payload',
        rvdSessionNonce,
        'test_for_failure');

    List<int> list = utf8.encode('$signedEnvelope\n');
    Uint8List data = Uint8List.fromList(list);

    late Function(Uint8List data) socketOnDataFn;
    MockSocket mockSocket = MockSocket();

    when(() => mockSocket.listen(any(),
        onError: any(named: "onError"),
        onDone: any(named: "onDone"))).thenAnswer((Invocation invocation) {
      socketOnDataFn = invocation.positionalArguments[0];

      socketOnDataFn(data);

      return MockStreamSubscription<Uint8List>();
    });

    bool somethingThrown = false;
    try {
      await sa.authenticate(mockSocket);
    } catch (_) {
      somethingThrown = true;
    }
    expect(somethingThrown, true);
  });

  test(
      'SignatureVerifyingSocketAuthenticator signature verification ok but mismatched nonce',
      () async {
    final uuidString = Uuid().v4().toString();
    String rvdSessionNonce = DateTime.now().toIso8601String();
    Map payload = {'sessionId': uuidString, 'rvdNonce': rvdSessionNonce};

    String signedEnvelope = signPayload(atChops, payload);
    SignatureAuthVerifier sa = SignatureAuthVerifier(
        atChops.atChopsKeys.atEncryptionKeyPair!.atPublicKey.publicKey,
        jsonEncode(payload),
        rvdSessionNonce,
        'test_for_mismatch');

    Map fakedEnvelope = jsonDecode(signedEnvelope);
    fakedEnvelope['payload']['rvdNonce'] = 'not the same nonce';
    List<int> list = utf8.encode('${jsonEncode(fakedEnvelope)}\n');
    Uint8List data = Uint8List.fromList(list);

    late Function(Uint8List data) socketOnDataFn;
    MockSocket mockSocket = MockSocket();

    when(() => mockSocket.listen(any(),
        onError: any(named: "onError"),
        onDone: any(named: "onDone"))).thenAnswer((Invocation invocation) {
      socketOnDataFn = invocation.positionalArguments[0];

      socketOnDataFn(data);

      return MockStreamSubscription<Uint8List>();
    });

    bool somethingThrown = false;
    try {
      await sa.authenticate(mockSocket);
    } catch (_) {
      somethingThrown = true;
    }
    expect(somethingThrown, true);
  });
}

String signPayload(AtChops atChops, Map payload) {
  Map envelope = {'payload': payload};

  final AtSigningInput signingInput = AtSigningInput(jsonEncode(payload))
    ..signingMode = AtSigningMode.data;
  final AtSigningResult sr = atChops.sign(signingInput);

  final String signature = sr.result.toString();
  envelope['signature'] = signature;
  envelope['hashingAlgo'] = sr.atSigningMetaData.hashingAlgoType!.name;
  envelope['signingAlgo'] = sr.atSigningMetaData.signingAlgoType!.name;
  return jsonEncode(envelope);
}

bool verifySignature(
  AtChops atChops,
  String requestingAtsign,
  Map envelope,
) {
  final String signature = envelope['signature'];
  Map payload = envelope['payload'];
  final hashingAlgo = HashingAlgoType.values.byName(envelope['hashingAlgo']);
  final signingAlgo = SigningAlgoType.values.byName(envelope['signingAlgo']);
  final pk = atChops.atChopsKeys.atEncryptionKeyPair!.atPublicKey.publicKey;
  AtSigningVerificationInput input = AtSigningVerificationInput(
      jsonEncode(payload), base64Decode(signature), pk)
    ..signingMode = AtSigningMode.data
    ..signingAlgoType = signingAlgo
    ..hashingAlgoType = hashingAlgo;

  AtSigningResult svr = atChops.verify(input);
  return svr.result;
}

class MockSocket extends Mock implements Socket {}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {}
