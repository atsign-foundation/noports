import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/pages/sub_nav_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:npt_flutter/widgets/switch_atsign_button.dart';

void main() {
  late SubNavCubit subNav;
  late List<String> calls;

  setUp(() {
    subNav = SubNavCubit()..setSubRoute(HomeRoutes.settings);
    calls = [];
  });

  /// Switches to @alice with a sign in that ends in [result].
  Future<void> switchTo(
    WidgetTester tester,
    NoPortsOnboardingResult? result,
  ) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: subNav,
        child: MaterialApp(
          navigatorKey: App.navState,
          home: const Text('home'),
          routes: {Routes.onboarding: (_) => const Text('onboarding')},
        ),
      ),
    );

    await switchToKeychainAtsign(
      '@alice'.toAtsign(),
      'root.atsign.org',
      signOut: () async {
        calls.add('sign out');
        return true;
      },
      signIn: (atsign, rootDomain) async {
        calls.add('sign in $atsign at $rootDomain');
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

    expect(calls, ['sign out', 'sign in @alice at root.atsign.org']);
    expect(find.text('home'), findsOneWidget);
    expect(subNav.state, HomeRoutes.settings);
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

      expect(calls, ['sign out', 'sign in @alice at root.atsign.org']);
      expect(find.text('onboarding'), findsOneWidget);
      expect(find.text('home', skipOffstage: false), findsNothing);
      expect(subNav.state, HomeRoutes.dashboard);
    });
  });
}
