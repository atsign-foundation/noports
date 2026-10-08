import 'package:flutter/material.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';

class SubNavObserver extends RouteObserver<PageRoute<dynamic>> {
  final SubNavCubit subNavCubit;

  SubNavObserver(this.subNavCubit);

  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    _updateSubRoute(route);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    // After a pop, the "current" route is previousRoute
    if (previousRoute != null) {
      _updateSubRoute(previousRoute);
    }
  }

  /// Helper to update the Cubit if the route has a valid name
  void _updateSubRoute(Route route) {
    if (route is PageRoute && route.settings.name != null) {
      subNavCubit.setSubRoute(route.settings.name!);
    }
  }
}
