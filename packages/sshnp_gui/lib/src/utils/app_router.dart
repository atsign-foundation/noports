import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/presentation/screens/new_connection_screen.dart';
import 'package:sshnp_gui/src/repository/navigation_service.dart';

import '../presentation/screens/home_screen.dart';
import '../presentation/screens/onboarding_screen.dart';

enum AppRoute { onboarding, home, newConnection }

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
                pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const HomeScreen(),
                    transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child))),
              ),
              GoRoute(
                path: 'new',
                name: AppRoute.newConnection.name,
                pageBuilder: (context, state) => CustomTransitionPage<void>(
                    key: state.pageKey,
                    child: const NewConnectionScreen(),
                    transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                        FadeTransition(opacity: animation, child: child))),
              )
            ]),
      ],
    ));
