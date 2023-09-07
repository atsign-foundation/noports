import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

final navIndexProvider = AutoDisposeNotifierProvider<NavIndexController, int>(NavIndexController.new);

class NavIndexController extends AutoDisposeNotifier<int> {
  @override
  int build() => 0;

  void goTo(AppRoute route) => state = route.index - 1;
  void goToIndex(int index) => state = index;
}

final terminalSSHCommandProvider = StateProvider<String>(
  (ref) => '',
);
