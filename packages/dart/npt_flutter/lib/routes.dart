import 'package:flutter/material.dart';

import 'pages/pages.dart';

class Routes {
  static const onboarding = '/';
  static const dashboard = '/dashboard';
  static const settings = '/settings';
  static const profileForm = '/profile';
  static const loadingPage = '/loading';

  static final Map<String, WidgetBuilder> routes = {
    onboarding: (_) => const OnboardingPage(nextRoute: dashboard),
    dashboard: (_) => const DashboardPage(),
    settings: (_) => const SettingsPage(),
    profileForm: (_) => const ProfileFormPage(),
    loadingPage: (_) => const LoadingPage(),
  };
}
