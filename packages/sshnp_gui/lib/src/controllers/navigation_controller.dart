import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sshnp_gui/src/presentation/screens/home_screen.dart';
import 'package:sshnp_gui/src/presentation/screens/onboarding_screen.dart';
import 'package:sshnp_gui/src/presentation/screens/profile_editor_screen.dart';
import 'package:sshnp_gui/src/presentation/screens/settings_screen.dart';
import 'package:sshnp_gui/src/presentation/screens/terminal_screen.dart';
import 'package:sshnp_gui/src/repository/navigation_repository.dart';

import '../presentation/screens/support_screen.dart';

enum AppRoute {
  onboarding,
  home,
  profileForm,
  terminal,
  blank, // This is a pace holder
  support,
  settings,
  // sshKeyManagementForm,
  // sskKeyManagement,
}

final navigationController = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: NavigationRepository.navKey,
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
                  FadeTransition(opacity: animation, child: child)),
            ),
          ),
          GoRoute(
            path: 'new',
            name: AppRoute.profileForm.name,
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const ProfileEditorScreen(),
              transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child)),
            ),
          ),
          GoRoute(
            path: 'terminal',
            name: AppRoute.terminal.name,
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const TerminalScreen(),
              transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child)),
            ),
          ),
          GoRoute(
            path: 'settings',
            name: AppRoute.settings.name,
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const SettingsScreen(),
              transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child)),
            ),
          ),
          GoRoute(
            path: 'support',
            name: AppRoute.support.name,
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: state.pageKey,
              child: const SupportScreen(),
              transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
                  FadeTransition(opacity: animation, child: child)),
            ),
          ),
          // ),
          // GoRoute(
          //   path: 'key-management',
          //   name: AppRoute.sskKeyManagement.name,
          //   pageBuilder: (context, state) => CustomTransitionPage<void>(
          //     key: state.pageKey,
          //     child: const SshKeyManagementScreen(),
          //     transitionsBuilder: ((context, animation, secondaryAnimation, child) =>
          //         FadeTransition(opacity: animation, child: child)),
          //   ),
          // )
        ],
      ),
    ],
  ),
);
