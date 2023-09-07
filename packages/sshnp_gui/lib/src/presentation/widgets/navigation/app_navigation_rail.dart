import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../controllers/minor_providers.dart';
import '../../../utils/app_router.dart';

class AppNavigationRail extends ConsumerWidget {
  const AppNavigationRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentNavIndexProvider);

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
                ? SvgPicture.asset('assets/images/nav_icons/new_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/new_unselected.svg'),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 2
                ? SvgPicture.asset('assets/images/nav_icons/pican_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/pican_unselected.svg'),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 3
                ? SvgPicture.asset('assets/images/nav_icons/settings_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/settings_unselected.svg'),
            label: const Text(''),
          ),
        ],
        selectedIndex: ref.watch(currentNavIndexProvider),
        onDestinationSelected: (int selectedIndex) {
          ref.read(currentNavIndexProvider.notifier).update((state) => selectedIndex);

          switch (selectedIndex) {
            case 0:
              context.goNamed(AppRoute.home.name);
              break;
            case 1:
              context.goNamed(AppRoute.newConnection.name);
              break;
            case 2:
              context.goNamed(AppRoute.terminal.name);
              break;
            case 3:
              context.goNamed(AppRoute.settings.name);
              break;
          }
        });
  }
}
