import 'package:noports_core/sshnp_foundation.dart';

import 'sshnp_mocks.dart';
import 'sshnp_core_constants.dart';

/// Mocked Classes
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
  late FunctionStub<Future<void>> _stubbedCallInitialization;
  late FunctionStub<Future<void>> _stubbedInitialize;
  late FunctionStub<void> _stubbedCompleteInitialization;

  void stubAsyncInitialization({
    required FunctionStub<Future<void>> stubbedCallInitialization,
    required FunctionStub<Future<void>> stubbedInitialize,
    required FunctionStub<void> stubbedCompleteInitialization,
  }) {
    _stubbedCallInitialization = stubbedCallInitialization;
    _stubbedInitialize = stubbedInitialize;
    _stubbedCompleteInitialization = stubbedCompleteInitialization;
  }

  @override
  Future<void> callInitialization() async {
    _stubbedCallInitialization();
    return super.callInitialization();
  }

  @override
  Future<void> initialize() async {
    _stubbedInitialize();
    await super.initialize();
  }

  @override
  void completeInitialization() {
    return _stubbedCompleteInitialization();
  }
}
