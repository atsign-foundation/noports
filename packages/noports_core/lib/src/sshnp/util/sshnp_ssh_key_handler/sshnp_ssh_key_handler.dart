import 'package:meta/meta.dart';
import 'package:noports_core/utils.dart';

mixin SshnpKeyHandler {
  @protected
  AtSshKeyUtil get keyUtil;

  @protected
  AtSshKeyPair? get identityKeyPair;
}
