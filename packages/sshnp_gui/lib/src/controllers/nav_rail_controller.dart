import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

final navRailController = AutoDisposeNotifierProvider<NavRailController, AppRoute>(NavRailController.new);

class NavRailController extends AutoDisposeNotifier<AppRoute> {
  @override
  AppRoute build() => AppRoute.home;

  void setRoute(AppRoute route) {
    state = route;
  }
}
