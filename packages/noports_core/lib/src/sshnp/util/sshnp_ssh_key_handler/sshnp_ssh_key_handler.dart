import 'package:meta/meta.dart';
import 'package:noports_core/utils.dart';

mixin SshnpKeyHandler {
  @protected
  @visibleForTesting
  AtSshKeyUtil get keyUtil;

  @protected
  @visibleForTesting
  AtSshKeyPair? get identityKeyPair;
}
