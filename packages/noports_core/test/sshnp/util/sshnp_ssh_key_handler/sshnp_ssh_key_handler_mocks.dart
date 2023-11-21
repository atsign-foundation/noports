import 'package:mocktail/mocktail.dart';
import 'package:noports_core/sshnp_foundation.dart';

class MockSshnpKeyHandler extends Mock with SshnpKeyHandler {}

class MockAtSshKeyUtil extends Mock implements AtSshKeyUtil {}

class MockAtSshKeyPair extends Mock implements AtSshKeyPair {}
