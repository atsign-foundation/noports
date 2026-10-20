import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/cubit/multi_activation_cubit.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';
import 'package:npt_flutter/features/onboarding/widgets/activation_dialog_initial.dart';
import 'package:npt_flutter/features/onboarding/widgets/atsign_selector.dart';
import 'package:npt_flutter/features/onboarding/widgets/sign_in_dialog.dart';
import 'package:npt_flutter/features/policy_form/widgets/at_signs_list_widget.dart';
import 'package:npt_flutter/features/profile/profile.dart';
import 'package:npt_flutter/features/profile_form/widgets/profile_device_at_sign_text_field.dart';
import 'package:npt_flutter/features/profile_form/widgets/profile_relay_at_sign_text_field.dart';
import 'package:npt_flutter/features/settings/settings.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/localization/app_localizations_en.dart';
import 'package:npt_flutter/util/language.dart';

import 'atsign_field_length_test.mocks.dart';

final _strings = AppLocalizationsEn();
final _longest = '@${'a' * 55}';
final _tooLong = '@${'a' * 56}';

Widget _app(Widget home, {List<BlocProvider> providers = const []}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider(create: (_) => EnableLoggingCubit()),
      BlocProvider(create: (_) => LogsCubit()),
      ...providers,
    ],
    child: MaterialApp(
      navigatorKey: App.navState,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: home),
    ),
  );
}

Future<ProfileBloc> _loadedProfileBloc(WidgetTester tester) async {
  final repo = MockProfileRepository();
  when(repo.getProfile('p1', useCache: anyNamed('useCache'))).thenAnswer(
    (_) async => Profile(
      'p1',
      displayName: 'p1',
      deviceName: 'd1',
      remotePort: 22,
      localPort: 0,
      sshnpdAtsign: '@device'.toAtsign(),
      relayAtsign: '@rv_am'.toAtsign(),
    ),
  );
  final bloc = ProfileBloc(repo, 'p1')..add(const ProfileLoadEvent());
  await tester.pump();
  expect(bloc.state, isA<ProfileLoadedState>());
  return bloc;
}

Profile _profile(ProfileBloc bloc) => (bloc.state as ProfileLoadedState).profile;

Future<void> _openDialog(
  WidgetTester tester,
  Widget dialog,
  OnboardingCubit onboarding,
  void Function(bool?) onClosed,
) async {
  await tester.pumpWidget(
    _app(
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            onClosed(
              await showDialog<bool>(context: context, builder: (_) => dialog),
            );
          },
          child: const Text('open'),
        ),
      ),
      providers: [
        BlocProvider<OnboardingCubit>.value(value: onboarding),
        BlocProvider<MultiActivationCubit>(
          create: (_) => MultiActivationCubit(),
        ),
      ],
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Finder get _atsignSelectorField => find.descendant(
  of: find.byType(AtsignSelector),
  matching: find.byType(TextFormField),
);

@GenerateNiceMocks([
  MockSpec<ProfileRepository>(),
  MockSpec<SettingsRepository>(),
])
void main() {
  setUpAll(() => WidgetController.hitTestWarningShouldBeFatal = true);
  tearDownAll(() => WidgetController.hitTestWarningShouldBeFatal = false);

  group("Given the profile form's device atSign field", () {
    testWidgets(
      'when it holds 56 characters after the @, then it shows the '
      "invalid-atSign message, Save's form check fails, the profile keeps "
      'its atSign, and nothing throws',
      (tester) async {
        final bloc = await _loadedProfileBloc(tester);
        final form = GlobalKey<FormState>();
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: Form(key: form, child: const ProfileDeviceAtsignTextField()),
            ),
          ),
        );
        await tester.pump();
        expect(find.widgetWithText(TextFormField, '@device'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), _tooLong);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorAtsignField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-atSign message',
        );
        expect(
          form.currentState!.validate(),
          isFalse,
          reason: "A1: Save doesn't go ahead, since it checks the form first",
        );
        expect(_profile(bloc).sshnpdAtsign, '@device');
      },
    );

    testWidgets(
      "when it holds 55 characters after the @, then Save's form check passes "
      'and the profile holds exactly that atSign',
      (tester) async {
        final bloc = await _loadedProfileBloc(tester);
        final form = GlobalKey<FormState>();
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: Form(key: form, child: const ProfileDeviceAtsignTextField()),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), _longest);
        await tester.pump();

        expect(find.text(_strings.validationErrorAtsignField), findsNothing);
        expect(form.currentState!.validate(), isTrue, reason: 'A2');
        expect(_profile(bloc).sshnpdAtsign, _longest, reason: 'A2');
      },
    );
  });

  group("Given the profile form's relay atSign field", () {
    testWidgets(
      'when it holds 56 characters after the @, then it shows the invalid '
      "relay message, Save's form check fails, the profile keeps its relay, "
      'and nothing throws',
      (tester) async {
        final bloc = await _loadedProfileBloc(tester);
        final form = GlobalKey<FormState>();
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: Form(key: form, child: const ProfileRelayAtsignTextField()),
            ),
          ),
        );
        await tester.pump();
        expect(find.widgetWithText(TextFormField, '@rv_am'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), _tooLong);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorRelayField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-relay message',
        );
        expect(
          form.currentState!.validate(),
          isFalse,
          reason: "A1: Save doesn't go ahead, since it checks the form first",
        );
        expect(_profile(bloc).relayAtsign, '@rv_am');
      },
    );

    testWidgets(
      "when it holds 55 characters after the @, then Save's form check passes "
      'and the profile holds exactly that relay',
      (tester) async {
        final bloc = await _loadedProfileBloc(tester);
        final form = GlobalKey<FormState>();
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: Form(key: form, child: const ProfileRelayAtsignTextField()),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), _longest);
        await tester.pump();

        expect(find.text(_strings.validationErrorRelayField), findsNothing);
        expect(form.currentState!.validate(), isTrue, reason: 'A2');
        expect(_profile(bloc).relayAtsign, _longest, reason: 'A2');
      },
    );
  });

  group("Given Settings' default relay field", () {
    late MockSettingsRepository repo;

    Future<SettingsBloc> loadedSettingsBloc(WidgetTester tester) async {
      repo = MockSettingsRepository();
      when(repo.getSettings()).thenAnswer(
        (_) async => Settings(
          relayAtsign: '@rv_eu'.toAtsign(),
          overrideRelay: false,
          viewLayout: PreferredViewLayout.minimal,
          language: Language.english,
        ),
      );
      when(repo.putSettings(any)).thenAnswer((_) async => true);
      final bloc = SettingsBloc(repo)..add(const SettingsLoadEvent());
      await tester.pump();
      expect(bloc.state, isA<SettingsLoadedState>());
      return bloc;
    }

    Atsign relayOf(SettingsBloc bloc) =>
        (bloc.state as SettingsLoadedState).settings.relayAtsign;

    testWidgets(
      'when it holds 56 characters after the @, then it shows the invalid '
      'relay message, the settings are neither changed nor saved, and '
      'nothing throws',
      (tester) async {
        final bloc = await loadedSettingsBloc(tester);
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: const SettingsRelayAtsignTextField(),
            ),
          ),
        );
        await tester.pump();
        expect(find.widgetWithText(TextFormField, '@rv_eu'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField), _tooLong);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorRelayField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-relay message',
        );
        expect(relayOf(bloc), '@rv_eu', reason: "A1: the edit doesn't go ahead");
        verifyNever(repo.putSettings(any));
      },
    );

    testWidgets(
      'when it holds 55 characters after the @, then the settings hold and '
      'save exactly that relay',
      (tester) async {
        final bloc = await loadedSettingsBloc(tester);
        await tester.pumpWidget(
          _app(
            BlocProvider.value(
              value: bloc,
              child: const SettingsRelayAtsignTextField(),
            ),
          ),
        );
        await tester.pump();

        await tester.enterText(find.byType(TextFormField), _longest);
        await tester.pump();

        expect(find.text(_strings.validationErrorRelayField), findsNothing);
        expect(relayOf(bloc), _longest, reason: 'A2');
        verify(
          repo.putSettings(
            argThat(
              predicate<Settings>((s) => s.relayAtsign == _longest, 'relay'),
            ),
          ),
        ).called(1);
      },
    );
  });

  group("Given the policy form's add-atSign field", () {
    testWidgets(
      'when it holds 56 characters after the @ and Add is pressed, then it '
      'shows the invalid-atSign message, nothing is added, and nothing throws',
      (tester) async {
        List<Atsign>? added;
        await tester.pumpWidget(
          _app(
            AtsignsListWidget(
              label: 'Users',
              atsigns: const [],
              isEditing: true,
              onChanged: (atsigns) => added = List.of(atsigns),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), _tooLong);
        await tester.pump();
        await _tapVisible(tester, find.text(_strings.add));
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorAtsignField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-atSign message',
        );
        expect(added, isNull, reason: "A1: Add doesn't go ahead");
        expect(find.byType(ListTile), findsNothing);
      },
    );

    testWidgets(
      'when it holds 55 characters after the @ and Add is pressed, then '
      'exactly that atSign is added',
      (tester) async {
        List<Atsign>? added;
        await tester.pumpWidget(
          _app(
            AtsignsListWidget(
              label: 'Users',
              atsigns: const [],
              isEditing: true,
              onChanged: (atsigns) => added = List.of(atsigns),
            ),
          ),
        );

        await tester.enterText(find.byType(TextFormField), _longest);
        await tester.pump();
        expect(find.text(_strings.validationErrorAtsignField), findsNothing);

        await _tapVisible(tester, find.text(_strings.add));
        await tester.pump();

        expect(added, [_longest], reason: 'A2');
      },
    );
  });

  group("Given the sign-in dialog's atSign field", () {
    testWidgets(
      'when it goes from 55 to 56 characters after the @ and Sign in is '
      "pressed, then it shows the invalid-atSign message, the dialog doesn't "
      'close, and nothing throws',
      (tester) async {
        final onboarding = OnboardingCubit();
        var closed = false;
        await _openDialog(
          tester,
          const SignInDialog(options: {}),
          onboarding,
          (_) => closed = true,
        );

        await tester.enterText(_atsignSelectorField, _longest);
        await tester.pump();
        await tester.enterText(_atsignSelectorField, _tooLong);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorAtsignField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-atSign message',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(ElevatedButton, _strings.signIn),
        );
        await tester.pumpAndSettle();

        expect(closed, isFalse, reason: "A1: Sign in doesn't go ahead");
        expect(find.byType(SignInDialog), findsOneWidget);
      },
    );

    testWidgets(
      'when it holds 55 characters after the @ and Sign in is pressed, then '
      'the dialog closes to sign in with exactly that atSign',
      (tester) async {
        final onboarding = OnboardingCubit();
        bool? result;
        var closed = false;
        await _openDialog(
          tester,
          const SignInDialog(options: {}),
          onboarding,
          (r) {
            result = r;
            closed = true;
          },
        );

        await tester.enterText(_atsignSelectorField, _longest);
        await tester.pump();
        await _tapVisible(
          tester,
          find.widgetWithText(ElevatedButton, _strings.signIn),
        );
        await tester.pumpAndSettle();

        expect(closed, isTrue, reason: 'A2');
        expect(result, isTrue, reason: 'A2');
        expect(onboarding.state.atsign, _longest, reason: 'A2');
      },
    );
  });

  group("Given the activation dialog's atSign field", () {
    testWidgets(
      'when it goes from 55 to 56 characters after the @ and Next is pressed, '
      "then it shows the invalid-atSign message, the dialog doesn't close, "
      'and nothing throws',
      (tester) async {
        final onboarding = OnboardingCubit();
        var closed = false;
        await _openDialog(
          tester,
          const ActivationDialogInitial(),
          onboarding,
          (_) => closed = true,
        );

        await tester.enterText(_atsignSelectorField, _longest);
        await tester.pump();
        await tester.enterText(_atsignSelectorField, _tooLong);
        await tester.pump();

        expect(tester.takeException(), isNull, reason: 'A3: nothing throws');
        expect(
          find.text(_strings.validationErrorAtsignField),
          findsOneWidget,
          reason: 'A1: the field shows the invalid-atSign message',
        );

        await _tapVisible(
          tester,
          find.widgetWithText(ElevatedButton, _strings.next),
        );
        await tester.pumpAndSettle();

        expect(closed, isFalse, reason: "A1: Next doesn't go ahead");
        expect(find.byType(ActivationDialogInitial), findsOneWidget);
      },
    );

    testWidgets(
      'when it holds 55 characters after the @, then Next is enabled with '
      'exactly that atSign as the one to activate',
      (tester) async {
        final onboarding = OnboardingCubit();
        await _openDialog(
          tester,
          const ActivationDialogInitial(),
          onboarding,
          (_) {},
        );

        await tester.enterText(_atsignSelectorField, _longest);
        await tester.pump();

        expect(find.text(_strings.validationErrorAtsignField), findsNothing);
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, _strings.next),
              )
              .onPressed,
          isNotNull,
          reason: 'A2',
        );
        expect(onboarding.state.atsign, _longest, reason: 'A2');
      },
    );
  });
}
