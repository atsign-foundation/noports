import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

final navRouteController = AutoDisposeNotifierProvider<NavRouteController, AppRoute>(NavRouteController.new);

class NavRouteController extends AutoDisposeNotifier<AppRoute> {
  @override
  AppRoute build() => AppRoute.home;

  void goTo(AppRoute route) => state = route;
}
