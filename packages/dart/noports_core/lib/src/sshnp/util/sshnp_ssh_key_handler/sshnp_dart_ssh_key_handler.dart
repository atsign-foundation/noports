import 'package:noports_core/sshnp_foundation.dart';

mixin SshnpDartSshKeyHandler implements SshnpKeyHandler {
  @override
  DartSshKeyUtil get keyUtil => _sshKeyUtil;
  final DartSshKeyUtil _sshKeyUtil = DartSshKeyUtil();

  @override
  AtSshKeyPair? identityKeyPair;
}
