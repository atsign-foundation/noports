import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/controllers/current_nav_index_provider.dart';

import '../../utils/app_router.dart';

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
                    'assets/images/nav_icons/home.svg',
                  ),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 1
                ? SvgPicture.asset('assets/images/nav_icons/new_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/new.svg'),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 2
                ? SvgPicture.asset('assets/images/nav_icons/picanonboard_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/picanonboard.svg'),
            label: const Text(''),
          ),
          NavigationRailDestination(
            icon: currentIndex == 3
                ? SvgPicture.asset('assets/images/nav_icons/settings_selected.svg')
                : SvgPicture.asset('assets/images/nav_icons/settings.svg'),
            label: const Text(''),
          ),
        ],
        selectedIndex: ref.watch(currentNavIndexProvider),
        onDestinationSelected: (int selectedIndex) {
          ref.read(currentNavIndexProvider.notifier).update((state) => selectedIndex);
          context.goNamed(AppRoute.home.name);
        });
  }
}
