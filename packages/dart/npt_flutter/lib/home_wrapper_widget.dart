import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/pages/sub_nav_observer.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/widgets/npt_app_bar.dart';

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
          return Scaffold(
            appBar: const NptAppBar(),
            body: Column(
              children: [
                Expanded(
                  child: Navigator(
                    key: wrapperNav,
                    initialRoute: HomeRoutes.dashboard,
                    observers: [
                      SubNavObserver(context.read<SubNavCubit>()),
                    ],
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
        },
      ),
    );
  }
}
