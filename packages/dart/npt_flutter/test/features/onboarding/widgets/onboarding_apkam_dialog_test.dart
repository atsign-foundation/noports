import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/widgets/onboarding_apkam_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/util/at_client_methods.dart';

void main() {
  setUp(() => AtClientManager.getInstance().reset());

  group('Given the enrollment dialog is waiting for a manager to decide a'
      ' request', () {
    testWidgets('when the atServer reports the request revoked, then the'
        ' dialog asks for a new OTP and says the request was revoked', (
      tester,
    ) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      pending.refuse(
        AtEnrollmentException(
          'Enrollment e1 was refused for a reason this wait cannot resolve: '
          'Failed connecting to @alice. '
          'error:AT0027-enrollment_id: e1 is revoked',
        ),
      );
      await _settle(tester);

      expect(dialog.closed, isFalse, reason: 'the dialog stays open');
      _expectOtpPrompt(tester);
      expect(
        find.text(_strings.errorEnrollmentRevoked),
        findsOneWidget,
        reason: 'the OTP prompt says the request was revoked',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });

    testWidgets('when the user presses Cancel, then the wait is cancelled,'
        ' which drops its pending keys, and the dialog then asks for a new OTP'
        ' and tells the user to deny the request in the Authenticator, with'
        ' nothing adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keysDropped = Completer<void>();
      pending.keysDropped = keysDropped.future;
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      await tester.tap(_cancelButton);
      await _settle(tester);

      expect(
        pending.cancels,
        1,
        reason: "Cancel cancels the request's wait, which drops its keys",
      );
      expect(
        find.byKey(const Key('otp')),
        findsNothing,
        reason: 'no new OTP is asked for until the pending keys are dropped',
      );
      expect(
        keychain.entries,
        contains('@alice'),
        reason: 'the keychain entry is left alone until the wait has ended',
      );

      keysDropped.complete();
      await _settle(tester);

      expect(dialog.closed, isFalse, reason: 'the dialog stays open');
      _expectOtpPrompt(tester);
      expect(
        find.text(_strings.cancelledRequestStillPending),
        findsOneWidget,
        reason: 'the OTP prompt tells the user to deny the cancelled request',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });

    testWidgets('when an approval lands and a Cancel press arrives before the'
        ' screen changes, then the wait is not cancelled and the approved'
        ' client is the one the app uses', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);
      final pressCancel = tester.widget<FilledButton>(_cancelButton).onPressed!;
      final client = _Client();

      pending.approve(client);
      await tester.idle();
      pressCancel();
      await _settle(tester);

      expect(
        pending.cancels,
        0,
        reason: 'a Cancel after the approval cancels nothing',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        same(client),
        reason: 'the approved client is adopted',
      );
      expect(client.stops, 0, reason: 'the approved client keeps running');
      expect(
        keychain.entries,
        contains('@alice'),
        reason: 'the approved keys stay in the keychain',
      );
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(
        dialog.result?.status,
        NoPortsOnboardingResultStatus.success,
        reason: 'the dialog closes as approved',
      );
    });

    testWidgets('when the dialog is closed while waiting, then the wait is'
        ' cancelled and nothing is adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      Navigator.of(App.navState.currentContext!).pop();
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog has closed');
      expect(
        pending.cancels,
        1,
        reason: "closing the dialog cancels the request's wait",
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });
  });
}

AppLocalizations get _strings =>
    AppLocalizations.of(App.navState.currentContext!)!;

Finder get _cancelButton => find.widgetWithText(FilledButton, _strings.cancel);

/// A request awaiting a decision the test makes. [cancel] ends the wait as
/// `PendingEnrollment.cancel` does, returning once [keysDropped] completes.
class _Pending extends Fake implements PendingEnrollment {
  final _decision = Completer<AtClient>();
  var cancels = 0;
  Future<void> keysDropped = Future.value();

  @override
  String get enrollmentId => 'e1';

  @override
  Future<AtClient> client(
    AtClientPreference preference, {
    String? namespace,
    required AtClientStorage storage,
    Duration? retryInterval,
    int? maxRetries,
    Duration? connectBudget,
  }) => _decision.future;

  @override
  Future<void> cancel() async {
    cancels++;
    if (!_decision.isCompleted) {
      _decision.completeError(
        AtEnrollmentCancelledException(
          'the wait for enrollment e1 of @alice was cancelled',
        ),
      );
    }
    await keysDropped;
  }

  void approve(AtClient client) => _decision.complete(client);

  void refuse(Object error) => _decision.completeError(error);
}

/// Resumes [pending], as if this device had submitted it before.
class _Flows extends Fake implements AtsignFlows {
  _Flows(this.pending);

  final PendingEnrollment pending;

  @override
  Future<PendingEnrollment?> resumeEnrollment(
    String atSign, {
    required String app,
    required String device,
    required WrittenAtKeysIo keys,
    required AtClientPreference preference,
    AtLookUpFactory? lookUps,
  }) async => pending;
}

/// A keychain holding an entry for @alice with nothing live in it, as a
/// request awaiting a decision leaves it.
class _Keychain extends Fake implements KeychainStorage {
  final entries = <String, AtKeys>{'@alice': AtKeys()};

  @override
  Future<AtKeys?> getAtsign(String atSign) async => entries[atSign];

  @override
  Future<void> removeAtsignFromKeychain(String atSign) async {
    entries.remove(atSign);
  }
}

class _Client extends Fake implements AtClient {
  var stops = 0;

  @override
  String? getCurrentAtSign() => '@alice';

  @override
  Future<void> stop() async {
    stops++;
  }
}

/// The open dialog, and what it closed with once it has.
class _Dialog {
  bool closed = false;
  NoPortsOnboardingResult? result;
}

/// Opens the dialog on [pending], with its keys in [keychain], and returns
/// once it is waiting for the decision.
Future<_Dialog> _open(
  WidgetTester tester,
  _Pending pending,
  _Keychain keychain,
) async {
  final dialog = _Dialog();
  unawaited(
    showDialog<NoPortsOnboardingResult>(
      context: App.navState.currentContext!,
      barrierDismissible: false,
      builder: (_) => OnboardingApkamDialog(
        atsign: '@alice'.toAtsign(),
        // ignore: deprecated_member_use
        atClientPreference: AtClientPreference()..hiveStoragePath = 'unused',
        flows: _Flows(pending),
        deviceName: () async => 'test device',
        keychain: keychain,
      ),
    ).then((result) {
      dialog.closed = true;
      dialog.result = result;
    }),
  );
  await _settle(tester);
  expect(
    find.byKey(const Key('activating')),
    findsOneWidget,
    reason: 'the dialog is waiting for the decision',
  );
  return dialog;
}

/// Lets the dialog's awaits finish and the frames they cause be built. The
/// waiting screen's spinner never settles, so this pumps a fixed number of
/// frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void _expectOtpPrompt(WidgetTester tester) {
  expect(
    find.byKey(const Key('otp')),
    findsOneWidget,
    reason: 'the dialog asks for a new OTP',
  );
  expect(
    tester.widget<EditableText>(find.byType(EditableText)).controller.text,
    isEmpty,
    reason: 'the OTP field is empty',
  );
}

/// Provides the app log [App.log] writes to and the app's strings, on a
/// desktop-sized window. The test font draws every glyph a full em wide, so
/// text is scaled down to fit the dialog as the app's own fonts do.
Future<void> _pumpApp(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(1920, 1080)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider(create: (_) => LogsCubit()),
      ],
      child: MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(0.5)),
          child: child!,
        ),
        home: const Scaffold(),
      ),
    ),
  );
}
