import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_flutter/src/controllers/navigation_controller.dart';
import 'package:sshnp_flutter/src/controllers/navigation_rail_controller.dart';
import 'package:sshnp_flutter/src/utility/sizes.dart';

import '../../../controllers/terminal_session_controller.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  static var activatedIcons = [
    SvgPicture.asset('assets/images/nav_icons/dashboard_selected.svg'),
    SvgPicture.asset('assets/images/nav_icons/current_connection_selected.svg'),
    gap0,
    SvgPicture.asset('assets/images/nav_icons/support_selected.svg'),
    SvgPicture.asset('assets/images/nav_icons/settings_selected.svg')
  ];

  static var deactivatedIcons = [
    SvgPicture.asset('assets/images/nav_icons/dashboard_unselected.svg'),
    SvgPicture.asset('assets/images/nav_icons/current_connection_unselected.svg'),
    gap0,
    SvgPicture.asset('assets/images/nav_icons/support_unselected.svg'),
    SvgPicture.asset('assets/images/nav_icons/settings_unselected.svg'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(navigationRailController.notifier);
    final terminalList = ref.watch(terminalSessionListController);
    final currentIndex = controller.getCurrentIndex();
    final height = MediaQuery.of(context).size.height;

    return Column(
      children: [
        SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight(
              child: NavigationRail(
                groupAlignment: -1,
                leading: SvgPicture.asset('assets/images/logo.svg'),
                destinations: controller.routes.map((AppRoute route) {
                  if (route == AppRoute.blank) {
                    return NavigationRailDestination(
                      icon: SizedBox(height: 116 + height - 467),
                      label: gap0,
                    );
                  } else if ((route == AppRoute.terminal && terminalList.isEmpty)) {
                    return const NavigationRailDestination(
                      icon: gapH46,
                      label: gap0,
                    );
                  } else {
                    return NavigationRailDestination(
                      icon: (controller.isCurrentIndex(route))
                          ? activatedIcons[controller.indexOf(route)]
                          : deactivatedIcons[controller.indexOf(route)],
                      label: gap0,
                    );
                  }
                }).toList(),
                selectedIndex: currentIndex,
                onDestinationSelected: (int selectedIndex) {
                  // Don't navigate for blank app route and terminal route if there are no sessions
                  if ((controller.getRoute(selectedIndex) == AppRoute.terminal && terminalList.isEmpty) ||
                      controller.getRoute(selectedIndex) == AppRoute.blank) {
                    return;
                  }
                  controller.setIndex(selectedIndex);
                  context.replaceNamed(controller.getCurrentRoute().name);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}
