import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';

class MockSshnpKeyHandler extends Mock with SshnpKeyHandler {}

class MockAtSshKeyUtil extends Mock implements AtSshKeyUtil {}

class MockAtSshKeyPair extends Mock implements AtSshKeyPair {}

class MockSshnpDartSshKeyHandler extends Mock with SshnpDartSshKeyHandler {}

class StubbedSshnp extends SshnpCore with SshnpLocalSshKeyHandler {
  @override
  LocalSshKeyUtil get keyUtil => _sshKeyUtil ?? (throw UnimplementedError());
  final LocalSshKeyUtil? _sshKeyUtil;

  StubbedSshnp({
    required super.atClient,
    required super.params,
    LocalSshKeyUtil? sshKeyUtil,
    SshnpdChannel? sshnpdChannel,
    SshrvdChannel? sshrvdChannel,
  })  : _sshKeyUtil = sshKeyUtil,
        _sshnpdChannel = sshnpdChannel,
        _sshrvdChannel = sshrvdChannel;

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
  bool get canRunShell => false;

  @override
  Future<SshnpRemoteProcess> runShell() {
    throw UnimplementedError();
  }
}

class MockLocalSshKeyUtil extends Mock implements LocalSshKeyUtil {}
