import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/pages.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/pages/sub_nav_observer.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

final GlobalKey<NavigatorState> wrapperNav = GlobalKey<NavigatorState>();

/// The top level tabs which can be restored when the home navigator is
/// rebuilt from scratch (e.g. after adding / switching atsign).
///
/// [HomeRoutes.profileForm] and [HomeRoutes.loadingPage] are deliberately
/// excluded: the former requires [ProfileFormPageArguments] which we cannot
/// reconstruct, and the latter is a transient route.
const Set<String> _restorableTabs = <String>{
  HomeRoutes.dashboard,
  HomeRoutes.settings,
  HomeRoutes.authorisation,
  HomeRoutes.policyManager,
};

Route<dynamic> _buildHomeRoute(RouteSettings settings) {
  final WidgetBuilder? builder = HomeRoutes.routes[settings.name];
  if (builder == null) {
    throw Exception('Route ${settings.name} not found');
  }
  return MaterialPageRoute<dynamic>(builder: builder, settings: settings);
}

class HomeWrapperWidget extends StatefulWidget {
  const HomeWrapperWidget({super.key});

  @override
  HomeWrapperWidgetState createState() => HomeWrapperWidgetState();
}

class HomeWrapperWidgetState extends State<HomeWrapperWidget> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: const NptAppBar(),
      body: Column(
        children: [
          Expanded(
            child: Navigator(
              key: wrapperNav,
              initialRoute: HomeRoutes.dashboard,
              observers: [SubNavObserver(context.read<SubNavCubit>())],
              onGenerateInitialRoutes: (navigator, initialRoute) =>
                  _generateInitialRoutes(),
              onGenerateRoute: (settings) => _buildHomeRoute(settings),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              strings.allRightsReserved,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Rebuilds the navigator stack so the tab which was selected before this
  /// wrapper was recreated stays selected. Falls back to the dashboard.
  List<Route<dynamic>> _generateInitialRoutes() {
    final String selected = context.read<SubNavCubit>().state;
    final List<Route<dynamic>> routes = <Route<dynamic>>[
      // The parent navigator initially pushes '/' as the route so needs to be
      // handled, even though the dashboard sits directly on top of it.
      _buildHomeRoute(const RouteSettings(name: '/')),
      _buildHomeRoute(const RouteSettings(name: HomeRoutes.dashboard)),
    ];

    if (selected != HomeRoutes.dashboard &&
        _restorableTabs.contains(selected)) {
      final Object? arguments = selected == HomeRoutes.policyManager
          ? PolicyPageArguments(context.read<OnboardingCubit>().getAtsign())
          : null;
      routes.add(
        _buildHomeRoute(RouteSettings(name: selected, arguments: arguments)),
      );
    }

    return routes;
  }
}
