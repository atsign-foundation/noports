import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/nav_route_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  static const indexedRoutes = [
    AppRoute.home,
    AppRoute.terminal,
    AppRoute.settings,
  ];

  static int getRouteIndex(AppRoute route) {
    return indexedRoutes.indexOf(route);
  }

  static var activatedIcons = [
    SvgPicture.asset('assets/images/nav_icons/home_selected.svg'),
    SvgPicture.asset('assets/images/nav_icons/pican_selected.svg'),
    SvgPicture.asset('assets/images/nav_icons/settings_selected.svg')
  ];

  static var deactivatedIcons = [
    SvgPicture.asset('assets/images/nav_icons/home_unselected.svg'),
    SvgPicture.asset('assets/images/nav_icons/pican_unselected.svg'),
    SvgPicture.asset('assets/images/nav_icons/settings_unselected.svg'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = getRouteIndex(ref.watch(navRouteController));

    return NavigationRail(
      destinations: indexedRoutes
          .map(
            (i) => NavigationRailDestination(
              icon: (currentIndex == getRouteIndex(i))
                  ? activatedIcons[getRouteIndex(i)]
                  : deactivatedIcons[getRouteIndex(i)],
              label: const Text(''),
            ),
          )
          .toList(),
      selectedIndex: indexedRoutes.indexOf(ref.watch(navRouteController)),
      onDestinationSelected: (int selectedIndex) {
        ref.read(navRouteController.notifier).goTo(indexedRoutes[selectedIndex]);
        context.goNamed(indexedRoutes[selectedIndex].name);
      },
    );
  }
}
