import 'package:noports_core/sshnp_foundation.dart';

mixin SshnpDartSshKeyHandler on SshnpCore implements SshnpKeyHandler {
  @override
  DartSshKeyUtil get keyUtil => _sshKeyUtil;
  final DartSshKeyUtil _sshKeyUtil = DartSshKeyUtil();

  @override
  AtSshKeyPair? get identityKeyPair => _identityKeyPair;
  AtSshKeyPair? _identityKeyPair;
}
