import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_mobile_flutter/pages/sub_nav_observer.dart';
import 'package:npt_mobile_flutter/routes.dart';
import 'package:npt_mobile_flutter/widgets/npt_app_bar.dart';

final GlobalKey<NavigatorState> wrapperNav = GlobalKey<NavigatorState>();

class HomeWrapperWidget extends StatefulWidget {
  const HomeWrapperWidget({super.key});

  @override
  HomeWrapperWidgetState createState() => HomeWrapperWidgetState();
}

class HomeWrapperWidgetState extends State<HomeWrapperWidget> {
  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return BlocProvider<SubNavCubit>(
      create: (_) => SubNavCubit(),
      child: Builder(
        builder: (context) {
          return BlocBuilder<SubNavCubit, String>(
            builder: (context, currentRoute) {
              return Scaffold(
                appBar: const NptAppBar(),
                body: Navigator(
                  key: wrapperNav,
                  initialRoute: HomeRoutes.dashboard,
                  observers: [SubNavObserver(context.read<SubNavCubit>())],
                  onGenerateRoute: (settings) {
                    final routeName = settings.name!;
                    final builder = HomeRoutes.routes[routeName];
                    if (builder != null) {
                      return MaterialPageRoute(
                        builder: builder,
                        settings: settings,
                      );
                    }
                    throw Exception('Route $routeName not found');
                  },
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: _getIndexFromRoute(currentRoute),
                  onTap: (index) {
                    final route = _getRouteFromIndex(index);
                    wrapperNav.currentState?.pushReplacementNamed(route);
                  },
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.dashboard_outlined),
                      activeIcon: const Icon(Icons.dashboard),
                      label: strings.dashboard,
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.settings_outlined),
                      activeIcon: const Icon(Icons.settings),
                      label: strings.settings,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  int _getIndexFromRoute(String route) {
    switch (route) {
      case HomeRoutes.dashboard:
        return 0;
      case HomeRoutes.settings:
        return 1;
      default:
        return 0;
    }
  }

  String _getRouteFromIndex(int index) {
    switch (index) {
      case 0:
        return HomeRoutes.dashboard;
      case 1:
        return HomeRoutes.settings;
      default:
        return HomeRoutes.dashboard;
    }
  }
}
