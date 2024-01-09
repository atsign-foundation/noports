import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/navigation_controller.dart';
import 'package:sshnp_gui/src/controllers/navigation_rail_controller.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

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
    final controller = ref.watch(navigationRailController.notifier);
    final currentIndex = controller.getCurrentIndex();

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height,
        ),
        child: IntrinsicHeight(
          child: NavigationRail(
            destinations: controller.routes
                .map(
                  (AppRoute route) => NavigationRailDestination(
                    icon: (controller.isCurrentIndex(route))
                        ? activatedIcons[controller.indexOf(route)]
                        : deactivatedIcons[controller.indexOf(route)],
                    label: const Text(''),
                  ),
                )
                .toList(),
            selectedIndex: currentIndex,
            onDestinationSelected: (int selectedIndex) {
              controller.setIndex(selectedIndex);
              context.goNamed(controller.getCurrentRoute().name);
            },
          ),
        ),
      ),
    );
  }
}
