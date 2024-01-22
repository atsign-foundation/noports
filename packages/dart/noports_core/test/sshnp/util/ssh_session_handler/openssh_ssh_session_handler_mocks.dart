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
mixin StubbedSshnpOpensshSshSessionHandler on OpensshSshSessionHandler {
  late StartInitialTunnelStub _stubbedStartInitialTunnel;
  late StartProcessStub _stubbedStartProcess;

  void stubSshnpOpensshSshSessionHandler({
    required StartInitialTunnelStub stubbedStartInitialTunnel,
    required StartProcessStub stubbedStartProcess,
  }) {
    _stubbedStartInitialTunnel = stubbedStartInitialTunnel;
    _stubbedStartProcess = stubbedStartProcess;
  }

  @override
  Future<Process?> startInitialTunnelSession({
    required String ephemeralKeyPairIdentifier,
    int? localRvPort,
    ProcessStarter startProcess = Process.start,
  }) {
    _stubbedStartInitialTunnel();
    return super.startInitialTunnelSession(
      ephemeralKeyPairIdentifier: ephemeralKeyPairIdentifier,
      localRvPort: localRvPort,
      startProcess: _stubbedStartProcess.call,
    );
  }
}

/// Stubbed Sshnp instance with the mixin
class StubbedSshnp extends SshnpCore
    with OpensshSshSessionHandler, StubbedSshnpOpensshSshSessionHandler {
  StubbedSshnp({
    required super.atClient,
    required super.params,
    required SshnpdChannel sshnpdChannel,
    required SrvdChannel srvdChannel,
  })  : _sshnpdChannel = sshnpdChannel,
        _srvdChannel = srvdChannel;

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
  SrvdChannel get srvdChannel => _srvdChannel;
  final SrvdChannel _srvdChannel;

  @override
  Future<Process?> startUserSession({required Process? tunnelSession}) {
    throw UnimplementedError();
  }

  @override
  bool get canRunShell => false;

  @override
  Future<SshnpRemoteProcess> runShell() {
    throw UnimplementedError();
  }
}
