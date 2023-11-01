import 'dart:async';

import 'package:at_client/at_client.dart';
import 'package:noports_core/src/common/ssh_key_utils.dart';
import 'package:noports_core/src/sshnp/sshnp_result.dart';
import 'package:noports_core/sshnp_core.dart';
import 'package:noports_core/sshnp_params.dart';
import 'package:test/test.dart';
import 'package:mocktail/mocktail.dart';

class MySSHNPCore extends SshnpCore {
  MySSHNPCore({
    required super.atClient,
    required super.params,
    shouldInitialize = false,
  });

  @override
  FutureOr<bool> handleSshnpdPayload(AtNotification notification) {
    // TODO: implement handleSshnpdPayload
    throw UnimplementedError();
  }

  @override
  // TODO: implement keyUtil
  AtSSHKeyUtil get keyUtil => throw UnimplementedError();

  @override
  FutureOr<SshnpResult> run() {
    // TODO: implement run
    throw UnimplementedError();
  }
}

class MockAtClient extends Mock implements AtClient {}

class MockSSHNPParams extends Mock implements SshnpParams {}

void main() {
  group('SSHNP Core', () {
    late AtClient atClient;
    late SshnpParams params;

    setUp(() {
      atClient = MockAtClient();
      params = MockSSHNPParams();
    });

    test('Constructor - expect that the namespace is set based on params', () {
      verifyNever(() => atClient.getPreferences());
      verifyNever(() => params.device);
      verifyNever(() => atClient.setPreferences(any()));

      when(() => atClient.getPreferences()).thenReturn(null);
      when(() => params.device).thenReturn('mydevice');
      when(() => atClient.setPreferences(any())).thenReturn(null);

      final sshnpCore = MySSHNPCore(atClient: atClient, params: params);

      verify(() => atClient.getPreferences()).called(1);
      verify(() => params.device).called(1);
      verify(() => atClient.setPreferences(any())).called(1);
    });
  });
}
