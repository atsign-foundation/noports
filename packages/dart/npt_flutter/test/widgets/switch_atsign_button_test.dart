import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/widgets/switch_atsign_button.dart';

void main() {
  late SubNavCubit subNav;
  late OnboardingCubit onboarding;
  late List<String> calls;
  String? cubitAtSignIn;

  setUp(() {
    subNav = SubNavCubit()..setSubRoute(HomeRoutes.settings);
    onboarding = OnboardingCubit()
      ..setState(atsign: '@bob'.toAtsign(), rootDomain: 'root.atsign.org');
    calls = [];
    cubitAtSignIn = null;
  });

  /// Switches from @bob to @alice, on another root, with a sign in that ends
  /// in [result], or throws [throws].
  Future<void> switchTo(
    WidgetTester tester,
    NoPortsOnboardingResult? result, {
    Object? throws,
  }) async {
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => EnableLoggingCubit()),
          BlocProvider(create: (_) => LogsCubit()),
          BlocProvider.value(value: subNav),
          BlocProvider.value(value: onboarding),
        ],
        child: MaterialApp(
          navigatorKey: App.navState,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('home')),
          routes: {
            Routes.onboarding: (_) => const Scaffold(body: Text('onboarding')),
          },
        ),
      ),
    );

    await switchToKeychainAtsign(
      '@alice'.toAtsign(),
      'vip.ve.atsign.zone',
      signOut: () async {
        calls.add('sign out');
        return true;
      },
      signIn: (atsign, rootDomain) async {
        calls.add('sign in $atsign at $rootDomain');
        cubitAtSignIn =
            '${onboarding.state.atsign} at ${onboarding.state.rootDomain}';
        if (throws != null) throw throws;
        return result;
      },
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a switch that signs in leaves the navigation to sign in', (
    tester,
  ) async {
    await switchTo(
      tester,
      NoPortsOnboardingResult.success(atsign: '@alice'.toAtsign()),
    );

    expect(calls, ['sign out', 'sign in @alice at vip.ve.atsign.zone']);
    expect(find.text('home'), findsOneWidget);
    expect(subNav.state, HomeRoutes.settings);
  });

  testWidgets('sign in sees the target atSign and its root in the onboarding '
      'cubit, which the onboarding util reads', (tester) async {
    await switchTo(
      tester,
      NoPortsOnboardingResult.success(atsign: '@alice'.toAtsign()),
    );

    expect(cubitAtSignIn, '@alice at vip.ve.atsign.zone');
  });

  final notSignedIn = <String, NoPortsOnboardingResult?>{
    'fails': NoPortsOnboardingResult.error(message: 'refused'),
    'is cancelled': NoPortsOnboardingResult.cancelled(),
    'is abandoned': null,
  };
  notSignedIn.forEach((outcome, result) {
    testWidgets('a switch whose sign in $outcome ends signed out, on the '
        'onboarding page', (tester) async {
      await switchTo(tester, result);

      expect(calls, ['sign out', 'sign in @alice at vip.ve.atsign.zone']);
      expect(find.text('onboarding'), findsOneWidget);
      expect(find.text('home', skipOffstage: false), findsNothing);
      expect(subNav.state, HomeRoutes.dashboard);
    });
  });

  testWidgets('a switch whose sign in throws says why, and ends signed out on '
      'the onboarding page', (tester) async {
    final error = Exception('keychain locked');

    await switchTo(tester, null, throws: error);

    expect(calls, ['sign out', 'sign in @alice at vip.ve.atsign.zone']);
    expect(find.text('onboarding'), findsOneWidget);
    expect(subNav.state, HomeRoutes.dashboard);
    expect(
      find.textContaining(
        describeOnboardingError(error, AppLocalizationsEn()),
        findRichText: true,
      ),
      findsOneWidget,
    );
  });
}
