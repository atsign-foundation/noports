import 'package:flutter/material.dart';

import 'pages/pages.dart';

class Routes {
  static const onboarding = '/';
  static const dashboard = '/dashboard';
  static const settings = '/settings';
  static const profileForm = '/profile';
  static const loadingPage = '/loading';

  static final Map<String, WidgetBuilder> routes = {
    onboarding: (_) => const OnboardingPage(
          nextRoute: dashboard,
          key: Key('onboarding_page'),
        ),
    dashboard: (_) => const DashboardPage(
          key: Key('dashboard_page'),
        ),
    settings: (_) => const SettingsPage(
          key: Key('settings_page'),
        ),
    profileForm: (_) => const ProfileFormPage(
          key: Key('profile_form_page'),
        ),
    loadingPage: (_) => const LoadingPage(
          key: Key('loading_page'),
        ),
  };
}
