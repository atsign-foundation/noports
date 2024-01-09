import 'package:noports_core/sshnp_foundation.dart';

import 'sshnp_mocks.dart';
import 'sshnp_core_constants.dart';

/// Mocked Classes
/// Stubbed [SshnpCore] (minimum viable implementation of [SshnpCore])
class StubbedSshnp extends SshnpCore with StubbedAsyncInitializationMixin {
  StubbedSshnp({
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

  @override
  bool get canRunShell => throw UnimplementedError();

  @override
  Future<SshnpRemoteProcess> runShell() {
    throw UnimplementedError();
  }
}

/// Stubbed mixin wrapper
mixin StubbedAsyncInitializationMixin on AsyncInitialization {
  late FunctionStub<void> _stubbedCallInitialization;
  late FunctionStub<void> _stubbedInitialize;
  late FunctionStub<void> _stubbedCompleteInitialization;

  void stubAsyncInitialization({
    required FunctionStub<void> stubbedCallInitialization,
    required FunctionStub<void> stubbedInitialize,
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
    super.completeInitialization();
    return _stubbedCompleteInitialization();
  }
}
