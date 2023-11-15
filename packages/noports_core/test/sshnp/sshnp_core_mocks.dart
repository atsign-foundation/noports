import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';

import 'sshnp_core_constants.dart';

/// Function Stubbing
abstract class FunctionCaller {
  void call();
}

class FunctionStub extends Mock implements FunctionCaller {}

/// Mocked Classes
class MockAtClient extends Mock implements AtClient {}

class MockSshnpParams extends Mock implements SshnpParams {}

class MockSshnpdChannel extends Mock implements SshnpdChannel {}

class MockSshrvdChannel extends Mock implements SshrvdChannel {}

/// Stubbed [SshnpCore] (minimum viable implementation of [SshnpCore])
class StubbedSshnpCore extends SshnpCore with StubbedAsyncInitializationMixin {
  StubbedSshnpCore({
    required super.atClient,
    required super.params,
    SshnpdChannel? sshnpdChannel,
    SshrvdChannel? sshrvdChannel,
  })  : _sshnpdChannel = sshnpdChannel,
        _sshrvdChannel = sshrvdChannel;

  @override
  Future<void> initialize() async {
    await super.initialize();
    completeInitialization();
  }

  @override
  AtSshKeyPair? get identityKeyPair => _identityKeyPair;
  final _identityKeyPair =
      AtSshKeyPair.fromPem(TestingKeyPair.private, identifier: 'testing');

  @override
  AtSshKeyUtil get keyUtil => throw UnimplementedError();

  @override
  Future<SshnpResult> run() => throw UnimplementedError();

  @override
  SshnpdChannel get sshnpdChannel =>
      _sshnpdChannel ?? (throw UnimplementedError());
  final SshnpdChannel? _sshnpdChannel;

  @override
  SshrvdChannel get sshrvdChannel =>
      _sshrvdChannel ?? (throw UnimplementedError());
  final SshrvdChannel? _sshrvdChannel;
}

/// Stubbed mixin wrapper
mixin StubbedAsyncInitializationMixin on AsyncInitialization {
  late FunctionStub _stubbedCallInitialization;
  late FunctionStub _stubbedInitialize;
  late FunctionStub _stubbedCompleteInitialization;

  void stubAsyncInitialization({
    required FunctionStub stubbedCallInitialization,
    required FunctionStub stubbedInitialize,
    required FunctionStub stubbedCompleteInitialization,
  }) {
    _stubbedCallInitialization = stubbedCallInitialization;
    _stubbedInitialize = stubbedInitialize;
    _stubbedCompleteInitialization = stubbedCompleteInitialization;
  }

  @override
  Future<void> callInitialization() async {
    _stubbedCallInitialization.call();
    return super.callInitialization();
  }

  @override
  Future<void> initialize() async {
    _stubbedInitialize.call();
    await super.initialize();
  }

  @override
  void completeInitialization() {
    _stubbedCompleteInitialization.call();
    super.completeInitialization();
  }
}
