import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';

final navigationRailController =
    AutoDisposeNotifierProvider<NavigationRailController, AppRoute>(
        NavigationRailController.new);

class NavigationRailController extends AutoDisposeNotifier<AppRoute> {
  @override
  AppRoute build() => AppRoute.home;

  final routes = [
    AppRoute.home,
    AppRoute.terminal,
    AppRoute.blank,
    AppRoute.support,
    AppRoute.settings,
  ];

  AppRoute getRoute(int index) {
    return routes[index];
  }

  int indexOf(AppRoute route) {
    return routes.indexOf(route);
  }

  bool isCurrentIndex(AppRoute route) {
    return state == route;
  }

  int getCurrentIndex() {
    return indexOf(state);
  }

  AppRoute getCurrentRoute() {
    return getRoute(getCurrentIndex());
  }

  bool setIndex(int index) {
    if (index < 0 || index >= routes.length) return false;
    state = routes[index];
    return true;
  }

  bool setRoute(AppRoute route) {
    if (!routes.contains(route)) return false;
    state = route;
    return true;
  }
}
