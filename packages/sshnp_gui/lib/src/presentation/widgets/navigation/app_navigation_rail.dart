import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/nav_index_controller.dart';
import 'package:sshnp_gui/src/utils/app_router.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(navIndexProvider);

    return NavigationRail(
        destinations: [
          NavigationRailDestination(
            icon: currentIndex == 0
                ? SvgPicture.asset('assets/images/nav_icons/home_selected.svg')
                : SvgPicture.asset(
                    'assets/images/nav_icons/home_unselected.svg',
                  ),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 1
                ? SvgPicture.asset('assets/images/nav_icons/pican_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/pican_unselected.svg'),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 2
                ? SvgPicture.asset('assets/images/nav_icons/settings_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/settings_unselected.svg'),
            label: const Text(''),
          ),
        ],
        selectedIndex: ref.watch(navIndexProvider),
        onDestinationSelected: (int selectedIndex) {
          ref.read(navIndexProvider.notifier).goToIndex(selectedIndex);
          switch (selectedIndex) {
            case 0:
              context.goNamed(AppRoute.home.name);
              break;
            case 1:
              context.goNamed(AppRoute.terminal.name);
              break;
            case 2:
              context.goNamed(AppRoute.settings.name);
              break;
          }
        });
  }
}
