import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/repository/navigation_service.dart';

import '../presentation/screens/home_screen.dart';
import '../presentation/screens/onboarding_screen.dart';

enum AppRoute { onboarding, home }

final goRouterProvider = Provider<GoRouter>((ref) => GoRouter(
      navigatorKey: NavigationService.navKey,
      initialLocation: '/',
      debugLogDiagnostics: false,
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) => const OnboardingScreen(),
            name: AppRoute.onboarding.name,
            routes: [
              GoRoute(
                path: 'home',
                name: AppRoute.home.name,
                builder: (context, state) => const HomeScreen(),
              )
            ]),
      ],
    ));
