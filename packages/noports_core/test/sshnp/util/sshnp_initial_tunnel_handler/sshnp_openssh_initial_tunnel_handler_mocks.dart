import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';

import '../../sshnp_mocks.dart';

/// Function Stubbing
abstract class StartInitialTunnelCaller {
  void call();
}

class StartInitialTunnelStub extends Mock implements StartInitialTunnelCaller {}

/// Stubbed Mixin that we are testing
mixin StubbedSshnpOpensshInitialTunnelHandler
    on SshnpOpensshInitialTunnelHandler {
  late StartInitialTunnelStub _stubbedStartInitialTunnel;
  late StartProcessStub _stubbedStartProcess;

  void stubSshnpOpensshInitialTunnelHandler({
    required StartInitialTunnelStub stubbedStartInitialTunnel,
    required StartProcessStub stubbedStartProcess,
  }) {
    _stubbedStartInitialTunnel = stubbedStartInitialTunnel;
    _stubbedStartProcess = stubbedStartProcess;
  }

  @override
  Future<Process?> startInitialTunnel({
    required String identifier,
    ProcessStarter startProcess = Process.start,
  }) {
    _stubbedStartInitialTunnel();
    return super.startInitialTunnel(
      identifier: identifier,
      startProcess: _stubbedStartProcess.call,
    );
  }
}

/// Stubbed Sshnp instance with the mixin
class StubbedSshnp extends SshnpCore
    with
        SshnpOpensshInitialTunnelHandler,
        StubbedSshnpOpensshInitialTunnelHandler {
  StubbedSshnp({
    required super.atClient,
    required super.params,
    required SshnpdChannel sshnpdChannel,
    required SshrvdChannel sshrvdChannel,
  })  : _sshnpdChannel = sshnpdChannel,
        _sshrvdChannel = sshrvdChannel;

  @override
  AtSshKeyPair? get identityKeyPair => throw UnimplementedError();

  @override
  AtSshKeyUtil get keyUtil => throw UnimplementedError();

  @override
  Future<SshnpResult> run() => throw UnimplementedError();

  @override
  SshnpdChannel get sshnpdChannel => _sshnpdChannel;
  final SshnpdChannel _sshnpdChannel;

  @override
  SshrvdChannel get sshrvdChannel => _sshrvdChannel;
  final SshrvdChannel _sshrvdChannel;
}
