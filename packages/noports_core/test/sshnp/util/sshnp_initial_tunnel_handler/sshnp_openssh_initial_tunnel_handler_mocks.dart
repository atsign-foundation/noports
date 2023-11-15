import 'package:at_client/at_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:noports_core/src/common/io_types.dart';
import 'package:noports_core/sshnp_foundation.dart';

/// Function Stubbing
abstract class StartInitialTunnelCaller {
  void call();
}

class StartInitialTunnelStub extends Mock implements StartInitialTunnelCaller {}

abstract class StartProcessCaller {
  Future<Process> call(
    String executable,
    List<String> arguments, {
    bool runInShell,
    ProcessStartMode mode,
  });
}

class StartProcessStub extends Mock implements StartProcessCaller {}

/// Mocked Classes
class MockAtClient extends Mock implements AtClient {}

class MockSshnpParams extends Mock implements SshnpParams {}

class MockSshnpdChannel extends Mock implements SshnpdChannel {}

class MockSshrvdChannel extends Mock implements SshrvdChannel {}

class MockProcess extends Mock implements Process {}

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
    _stubbedStartInitialTunnel.call();
    return super.startInitialTunnel(
      identifier: identifier,
      startProcess: _stubbedStartProcess.call,
    );
  }
}
