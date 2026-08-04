import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

import 'pages/pages.dart';

class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';

  static final Map<String, WidgetBuilder> routes = {
    onboarding: (_) => const OnboardingPage(),
    home: (_) => const HomeWrapperWidget(),
  };
}

class HomeRoutes {
  static const dashboard = '/dashboard';
  static const settings = '/settings';
  static const authorization = '/authorization';
  static const profileForm = '/profile';
  static const loadingPage = '/loading';
  static const policyManager = '/policy-manager';

  static final Map<String, WidgetBuilder> routes = {
    // The parent navigator initially pushes '/' as the route so needs to be handled.
    // Even though it then instantly pushes the Dashboard page.
    '/': (_) => const SizedBox.shrink(),
    dashboard: (_) => const ConnectionsPage(),
    settings: (_) => const SettingsPage(),
    authorization: (_) => const AuthorizationPage(),
    profileForm: (_) => const ProfileFormPage(),
    loadingPage: (_) => const LoadingPage(),
    policyManager: (_) => const PolicyPage(),
  };
}

String routeName(String route) {
  final uncapitalized = route.split('/').last;
  final capitalized =
      uncapitalized[0].toUpperCase() + uncapitalized.substring(1);
  final strings = AppLocalizations.of(App.navState.currentContext!)!;
  switch (capitalized) {
    case 'Dashboard':
      return strings.dashboard;
    case 'Settings':
      return strings.settings;
    case 'Authorization':
      return 'Authorization';
    case 'Profile':
      return strings.profile;
    case 'Loading':
      return strings.loading;
    case 'Policy-manager':
      return strings.policyManager;
    case 'Manage-atsign':
      return strings.manageAtsigns;
    default:
  }
  return capitalized;
}
