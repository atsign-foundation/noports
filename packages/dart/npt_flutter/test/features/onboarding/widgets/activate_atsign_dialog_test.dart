import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show Request, Response;
import 'package:http/testing.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/features/onboarding/widgets/activate_atsign_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';

void main() {
  group('Given the activation dialog is asking the registrar for a PIN', () {
    testWidgets('when the request fails, then the dialog closes with the error'
        ' "Failed to request an OTP…", and the app log names the error\'s'
        ' type', (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()..login = _fails;

      final dialog = await _open(tester, registrar);
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog closes');
      expect(dialog.result?.status, NoPortsOnboardingResultStatus.error);
      expect(
        dialog.result?.message,
        _strings.errorOtpRequestFailed,
        reason: 'the dialog closes with the PIN request error',
      );
      expect(
        _lines(logs),
        contains(contains('HandshakeException')),
        reason: "the app log names the error's type",
      );
    });

    testWidgets('when the request fails because the reply is not JSON, then'
        ' the dialog closes with the error "Failed to request an OTP…", and'
        " the app log names the error's type", (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()
        ..login = () async => Response('<html></html>', 200);

      final dialog = await _open(tester, registrar);
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog closes');
      expect(
        dialog.result?.message,
        _strings.errorOtpRequestFailed,
        reason: 'the dialog closes with the PIN request error',
      );
      expect(
        _lines(logs),
        contains(contains('FormatException')),
        reason: "the app log names the error's type",
      );
    });

    testWidgets('when the request fails because the reply is JSON but not an'
        ' object, then the dialog closes with the error "Failed to request an'
        ' OTP…", and the app log names the error\'s type', (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()..login = () async => Response('[]', 200);

      final dialog = await _open(tester, registrar);
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog closes');
      expect(
        dialog.result?.message,
        _strings.errorOtpRequestFailed,
        reason: 'the dialog closes with the PIN request error',
      );
      expect(
        _lines(logs),
        contains(contains('TypeError')),
        reason: "the app log names the error's type",
      );
    });

    testWidgets("when the registrar refuses with a reply that isn't JSON or"
        ' has no message, then the dialog closes with "Failed to request an'
        ' OTP…" rather than the reply\'s text', (tester) async {
      await _pumpApp(tester);
      for (final refusal in [
        Response('<html><body>502 Bad Gateway</body></html>', 502),
        Response(jsonEncode({'message': ''}), 500),
        Response(jsonEncode({'message': '  '}), 500),
        Response(jsonEncode({'message': []}), 500),
        Response(jsonEncode({'message': {}}), 500),
        Response(jsonEncode({'message': 42}), 500),
        Response(jsonEncode({'message': true}), 500),
        Response('[]', 500),
      ]) {
        final registrar = _Registrar()..login = () async => refusal;
        final dialog = await _open(tester, registrar);
        await _settle(tester);

        expect(
          dialog.result?.message,
          _strings.errorOtpRequestFailed,
          reason:
              'a ${refusal.statusCode} refusal with no message closes with'
              ' the PIN request error',
        );
      }
    });

    testWidgets('when the registrar refuses with a message, then the dialog'
        ' closes with that message', (tester) async {
      await _pumpApp(tester);
      final registrar = _Registrar()
        ..login = () async =>
            Response(jsonEncode({'message': 'Atsign not found'}), 404);
      final dialog = await _open(tester, registrar);
      await _settle(tester);

      expect(
        dialog.result?.message,
        'Atsign not found',
        reason: "the dialog closes with the registrar's message",
      );
    });

    testWidgets('when the request times out, then the dialog closes with the'
        " same error, and the app log names the error's type", (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()..login = _neverAnswers;

      final dialog = await _open(tester, registrar);
      await tester.pump(const Duration(seconds: 29));
      expect(dialog.closed, isFalse, reason: 'still waiting at 29 seconds');
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(dialog.closed, isTrue, reason: 'the dialog closes at 30 seconds');
      await _settle(tester);

      expect(dialog.result?.status, NoPortsOnboardingResultStatus.error);
      expect(
        dialog.result?.message,
        _strings.errorOtpRequestFailed,
        reason: 'the dialog closes with the PIN request error',
      );
      expect(
        _lines(logs),
        contains(contains('TimeoutException')),
        reason: "the app log names the error's type",
      );
    });
  });

  group('Given the activation dialog is waiting for the PIN', () {
    testWidgets("when Resend's request fails or times out, then the dialog"
        ' stays on the PIN step with Cancel, Resend and Confirm, and shows'
        ' "Failed to request an OTP…"', (tester) async {
      await _pumpApp(tester);
      final registrar = _Registrar();
      final dialog = await _open(tester, registrar);
      await _settle(tester);
      _expectPinStep(tester, 'before Resend');

      registrar.login = _fails;
      await tester.tap(find.byKey(_resend));
      await _settle(tester);

      expect(
        dialog.closed,
        isFalse,
        reason: 'a failed Resend keeps the dialog',
      );
      _expectPinStep(tester, 'after a failed Resend');
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'a failed Resend says the PIN request failed',
      );

      await tester.pump(const Duration(seconds: 10));
      await _settle(tester);
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsNothing,
        reason: 'the first message has gone before Resend times out',
      );

      registrar.login = _neverAnswers;
      await tester.tap(find.byKey(_resend));
      await tester.pump(const Duration(seconds: 29));
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsNothing,
        reason: 'Resend still waits at 29 seconds',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'a Resend that times out says the PIN request failed',
      );
      await _settle(tester);

      expect(
        dialog.closed,
        isFalse,
        reason: 'a Resend timeout keeps the dialog',
      );
      _expectPinStep(tester, 'after a Resend that times out');
    });

    for (final (outcome, answerWith) in [
      (
        'fails',
        (Completer<Response> answer) =>
            answer.completeError(HandshakeException('test')),
      ),
      (
        'is refused',
        (Completer<Response> answer) => answer.complete(Response('{}', 500)),
      ),
    ]) {
      testWidgets("when Resend's request $outcome while another dialog covers"
          ' this one, then "Failed to request an OTP…" is still shown', (
        tester,
      ) async {
        await _pumpApp(tester);
        final registrar = _Registrar();
        await _open(tester, registrar);
        await _settle(tester);

        final resendAnswer = Completer<Response>();
        registrar.login = () => resendAnswer.future;
        await tester.tap(find.byKey(_resend));
        await tester.pump();
        unawaited(
          showDialog<void>(
            context: App.navState.currentContext!,
            builder: (_) => const Text('covering'),
          ),
        );
        await _settle(tester);

        answerWith(resendAnswer);
        await _settle(tester);

        expect(
          find.text(_strings.errorOtpRequestFailed),
          findsOneWidget,
          reason:
              'a Resend that $outcome is reported while another dialog'
              ' covers it',
        );
      });
    }

    testWidgets('when the registrar refuses Resend, then the dialog stays on'
        ' the PIN step with Cancel, Resend and Confirm, and shows "Failed to'
        ' request an OTP…"', (tester) async {
      await _pumpApp(tester);
      final registrar = _Registrar();
      final dialog = await _open(tester, registrar);
      await _settle(tester);

      registrar.login = () async =>
          Response(jsonEncode({'message': 'Sent Successfully'}), 500);
      await tester.tap(find.byKey(_resend));
      await _settle(tester);

      expect(
        dialog.closed,
        isFalse,
        reason: 'a refused Resend keeps the dialog',
      );
      _expectPinStep(tester, 'after a refused Resend');
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'a refused Resend says the PIN request failed',
      );
    });
  });

  group('Given the user has entered the PIN and pressed Confirm', () {
    testWidgets('when the verification request fails, then the dialog goes'
        ' back to the PIN step, clears the PIN, makes Cancel, Resend and'
        ' Confirm available, and shows "Failed to verify the OTP…", and the'
        " app log names the error's type", (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()..validate = _fails;
      final dialog = await _open(tester, registrar);
      await _settle(tester);

      await _confirmPin(tester);
      await _settle(tester);

      expect(dialog.closed, isFalse, reason: 'the dialog stays open');
      _expectBackAtPinStep(tester);
      expect(
        find.text(_strings.errorOtpVerificationFailed),
        findsOneWidget,
        reason: 'the dialog says verifying the PIN failed',
      );
      expect(
        _lines(logs),
        contains(contains('HandshakeException')),
        reason: "the app log names the error's type",
      );

      await tester.enterText(find.byType(EditableText), '5678');
      await tester.pump();
      expect(
        tester.widget<TextButton>(find.byKey(_confirm)).onPressed,
        isNotNull,
        reason: 'Confirm can be pressed once a new PIN is entered',
      );
    });

    testWidgets('when the verification request fails while "Failed to request'
        ' an OTP…" is still showing, then "Failed to verify the OTP…" replaces'
        ' it', (tester) async {
      await _pumpApp(tester);
      final registrar = _Registrar()..validate = _fails;
      await _open(tester, registrar);
      await _settle(tester);
      registrar.login = _fails;
      await tester.tap(find.byKey(_resend));
      await _settle(tester);
      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'the failed Resend is still being reported',
      );

      await _confirmPin(tester);
      await _settle(tester);

      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsNothing,
        reason: 'the earlier message is cleared',
      );
      expect(
        find.text(_strings.errorOtpVerificationFailed),
        findsOneWidget,
        reason: 'the dialog says verifying the PIN failed',
      );
    });

    testWidgets('when the verification request times out, then the dialog'
        ' goes back to the PIN step, clears the PIN, makes Cancel, Resend and'
        ' Confirm available, and shows "Failed to verify the OTP…", and the'
        " app log names the error's type", (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()..validate = _neverAnswers;
      final dialog = await _open(tester, registrar);
      await _settle(tester);

      await _confirmPin(tester);
      await tester.pump(const Duration(seconds: 29));
      expect(
        find.byKey(_cancel),
        findsNothing,
        reason: 'still activating at 29 seconds',
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(
        find.byKey(_cancel),
        findsOneWidget,
        reason: 'back at the PIN step at 30 seconds',
      );
      await _settle(tester);

      expect(dialog.closed, isFalse, reason: 'the dialog stays open');
      _expectBackAtPinStep(tester);
      expect(
        find.text(_strings.errorOtpVerificationFailed),
        findsOneWidget,
        reason: 'the dialog says verifying the PIN failed',
      );
      expect(
        _lines(logs),
        contains(contains('TimeoutException')),
        reason: "the app log names the error's type",
      );
    });

    testWidgets('when the verification reply is not JSON, then the dialog goes'
        ' back to the PIN step, clears the PIN, and shows "Failed to verify the'
        ' OTP…", and no app log line holds the reply\'s text', (tester) async {
      const key = '0123456789abcdef0123456789abcdef';
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()
        ..validate = () async => Response('{"cramkey":"$key', 200);
      await _open(tester, registrar);
      await _settle(tester);

      await _confirmPin(tester);
      await _settle(tester);

      _expectBackAtPinStep(tester);
      expect(
        find.text(_strings.errorOtpVerificationFailed),
        findsOneWidget,
        reason: 'the dialog says verifying the PIN failed',
      );
      expect(
        _lines(logs),
        contains(contains('FormatException')),
        reason: "the app log names the error's type",
      );
      expect(
        _lines(logs).where((line) => line.contains(key)),
        isEmpty,
        reason: "no app log line may hold the reply's text",
      );
    });

    testWidgets('when the verification reply is JSON but not an object, then'
        ' the dialog goes back to the PIN step, clears the PIN, and shows'
        ' "Failed to verify the OTP…", and the app log names the error\'s'
        ' type', (tester) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar()
        ..validate = () async => Response('[]', 200);
      await _open(tester, registrar);
      await _settle(tester);

      await _confirmPin(tester);
      await _settle(tester);

      _expectBackAtPinStep(tester);
      expect(
        find.text(_strings.errorOtpVerificationFailed),
        findsOneWidget,
        reason: 'the dialog says verifying the PIN failed',
      );
      expect(
        _lines(logs),
        contains(contains('TypeError')),
        reason: "the app log names the error's type",
      );
    });

    testWidgets("when the registrar refuses with a reply that isn't JSON or"
        ' has no message, then the dialog goes back to the PIN step and shows'
        ' "Failed to verify the OTP…" rather than the reply\'s text', (
      tester,
    ) async {
      final logs = await _pumpApp(tester);
      final registrar = _Registrar();
      await _open(tester, registrar);
      await _settle(tester);

      for (final refusal in [
        Response('<html><body>502 Bad Gateway</body></html>', 502),
        Response('{}', 200),
        Response(jsonEncode({'message': {}}), 400),
        Response('[]', 500),
      ]) {
        registrar.validate = () async => refusal;
        await _confirmPin(tester);
        await _settle(tester);

        _expectBackAtPinStep(tester);
        expect(
          find.text(_strings.errorOtpVerificationFailed),
          findsOneWidget,
          reason:
              'a ${refusal.statusCode} refusal with no message says verifying'
              ' the PIN failed',
        );
      }
      expect(
        _lines(logs).where((line) => line.contains('Bad Gateway')),
        isEmpty,
        reason: "no app log line holds the reply's text",
      );
    });

    testWidgets('when the registrar refuses the PIN with a message, then the'
        " dialog goes back to the PIN step, clears the PIN, and shows the"
        " registrar's message", (tester) async {
      await _pumpApp(tester);
      final registrar = _Registrar()
        ..validate = () async =>
            Response(jsonEncode({'message': 'The OTP has expired'}), 400);
      await _open(tester, registrar);
      await _settle(tester);

      await _confirmPin(tester);
      await _settle(tester);

      _expectBackAtPinStep(tester);
      expect(
        find.text('The OTP has expired'),
        findsOneWidget,
        reason: "the dialog shows the registrar's message",
      );
    });
  });

  group("Given the user pressed Resend and then Confirm before Resend's reply"
      ' arrived', () {
    testWidgets("when Resend's reply arrives while the PIN is being verified,"
        ' then the dialog stays on "activating" and starts no second'
        ' verification', (tester) async {
      await _pumpApp(tester);
      final resendAnswer = await _resendThenConfirm(tester);

      resendAnswer.complete(_sent());
      await _settle(tester);

      expect(
        find.byKey(_confirm),
        findsNothing,
        reason: 'the dialog stays on "activating", with no Confirm to press',
      );
      await tester.pump(const Duration(seconds: 30));
      await _settle(tester);
    });

    testWidgets("when Resend's request fails while the PIN is being verified,"
        ' then the dialog still says "Failed to request an OTP…"', (
      tester,
    ) async {
      await _pumpApp(tester);
      final resendAnswer = await _resendThenConfirm(tester);

      resendAnswer.completeError(HandshakeException('test'));
      await _settle(tester);

      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'a failed Resend is reported even while the PIN is verified',
      );
      await tester.pump(const Duration(seconds: 30));
      await _settle(tester);
    });

    testWidgets('when Resend is refused while the PIN is being verified, then'
        ' the dialog still says "Failed to request an OTP…"', (tester) async {
      await _pumpApp(tester);
      final resendAnswer = await _resendThenConfirm(tester);

      resendAnswer.complete(Response('{}', 500));
      await _settle(tester);

      expect(
        find.text(_strings.errorOtpRequestFailed),
        findsOneWidget,
        reason: 'a refused Resend is reported even while the PIN is verified',
      );
      await tester.pump(const Duration(seconds: 30));
      await _settle(tester);
    });
  });

  group(
    'Given the user pressed Cancel while the dialog was asking for a PIN',
    () {
      testWidgets('when the registrar answers afterwards, then nothing more'
          ' happens: the result stays "cancelled" and no error is raised', (
        tester,
      ) async {
        await _pumpApp(tester);
        final answer = Completer<Response>();
        final registrar = _Registrar()..login = () => answer.future;
        final dialog = await _open(tester, registrar);

        await tester.tap(find.byKey(_cancel));
        await _settle(tester);
        expect(dialog.closed, isTrue, reason: 'Cancel closes the dialog');

        answer.complete(_sent());
        await _settle(tester);

        expect(dialog.result?.status, NoPortsOnboardingResultStatus.cancel);
      });

      testWidgets('when the request fails afterwards, then the result stays'
          ' "cancelled" and no error is raised', (tester) async {
        await _pumpApp(tester);
        final answer = Completer<Response>();
        final registrar = _Registrar()..login = () => answer.future;
        final dialog = await _open(tester, registrar);

        await tester.tap(find.byKey(_cancel));
        await _settle(tester);
        expect(dialog.closed, isTrue, reason: 'Cancel closes the dialog');

        answer.completeError(HandshakeException('test'));
        await _settle(tester);

        expect(dialog.result?.status, NoPortsOnboardingResultStatus.cancel);
      });

      testWidgets('when the request times out afterwards, then the result stays'
          ' "cancelled" and no error is raised', (tester) async {
        await _pumpApp(tester);
        final registrar = _Registrar()..login = _neverAnswers;
        final dialog = await _open(tester, registrar);

        await tester.tap(find.byKey(_cancel));
        await _settle(tester);
        expect(dialog.closed, isTrue, reason: 'Cancel closes the dialog');

        await tester.pump(const Duration(seconds: 30));
        await _settle(tester);

        expect(dialog.result?.status, NoPortsOnboardingResultStatus.cancel);
      });

      for (final (outcome, answerWith) in [
        (
          'fails',
          (Completer<Response> answer) =>
              answer.completeError(HandshakeException('test')),
        ),
        (
          'is refused',
          (Completer<Response> answer) => answer.complete(Response('{}', 500)),
        ),
      ]) {
        testWidgets('when the request $outcome while the dialog is still'
            ' closing, then the page beneath it stays open and the result'
            ' stays "cancelled"', (tester) async {
          await _pumpApp(tester);
          unawaited(
            App.navState.currentState!.push(
              MaterialPageRoute<void>(builder: (_) => const Text('beneath')),
            ),
          );
          await _settle(tester);
          final answer = Completer<Response>();
          final registrar = _Registrar()..login = () => answer.future;
          final dialog = await _open(tester, registrar);
          await _settle(tester);

          await tester.tap(find.byKey(_cancel));
          await tester.pump(const Duration(milliseconds: 50));
          answerWith(answer);
          await _settle(tester);

          expect(
            find.text('beneath'),
            findsOneWidget,
            reason: 'the page beneath the dialog stays open',
          );
          expect(dialog.result?.status, NoPortsOnboardingResultStatus.cancel);
        });
      }

      testWidgets('when the request times out while the dialog is still'
          ' closing, then the page beneath it stays open and the result stays'
          ' "cancelled"', (tester) async {
        await _pumpApp(tester);
        unawaited(
          App.navState.currentState!.push(
            MaterialPageRoute<void>(builder: (_) => const Text('beneath')),
          ),
        );
        await _settle(tester);
        final registrar = _Registrar()..login = _neverAnswers;
        final dialog = await _open(tester, registrar);
        await tester.pump(const Duration(milliseconds: 29900));

        await tester.tap(find.byKey(_cancel));
        await tester.pump(const Duration(milliseconds: 100));
        await _settle(tester);

        expect(
          find.text('beneath'),
          findsOneWidget,
          reason: 'the page beneath the dialog stays open',
        );
        expect(dialog.result?.status, NoPortsOnboardingResultStatus.cancel);
      });
    },
  );
}

const _cancel = Key('NoPortsActivateCancelButton');
const _resend = Key('NoPortsActivateResendButton');
const _confirm = Key('NoPortsActivateConfirmButton');

AppLocalizations get _strings =>
    AppLocalizations.of(App.navState.currentContext!)!;

Response _sent() => Response(jsonEncode({'message': 'Sent Successfully'}), 200);

Future<Response> _fails() async => throw HandshakeException('test');

Future<Response> _neverAnswers() => Completer<Response>().future;

/// A registrar whose answer to each endpoint the test sets: PIN requests are
/// sent unless [login] says otherwise, and verification is refused unless
/// [validate] says otherwise.
class _Registrar {
  Future<Response> Function() login = () async => _sent();
  Future<Response> Function() validate = () async => Response('{}', 500);

  late final client = MockClient(
    (Request request) =>
        request.url.path == NoPortsActivateApiEndpoints.validate.path
        ? validate()
        : login(),
  );
}

class _UnusedOnboardingUtil extends Fake implements NoPortsOnboardingUtil {}

/// The open dialog, and what it closed with once it has.
class _Dialog {
  bool closed = false;
  NoPortsOnboardingResult? result;
}

Future<_Dialog> _open(WidgetTester tester, _Registrar registrar) async {
  final dialog = _Dialog();
  unawaited(
    showDialog<NoPortsOnboardingResult>(
      context: App.navState.currentContext!,
      barrierDismissible: false,
      builder: (_) => ActivateAtsignDialog(
        atsign: '@alice'.toAtsign(),
        apiKey: 'unused',
        rootDomain: 'root.atsign.org',
        registrarUrl: 'unused',
        waitForTeapot: false,
        onboardingUtil: _UnusedOnboardingUtil(),
        activateUtil: ActivateUtil(
          registrarUrl: 'unused',
          apiKey: 'unused',
          client: registrar.client,
        ),
      ),
    ).then((result) {
      dialog.closed = true;
      dialog.result = result;
    }),
  );
  await tester.pump();
  return dialog;
}

/// Lets pending requests answer and the frames they cause be built. The
/// dialog's spinner never settles, so this pumps a fixed number of frames.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Presses Resend, then Confirm while Resend is unanswered and verification
/// never answers, and returns the completer that answers Resend.
Future<Completer<Response>> _resendThenConfirm(WidgetTester tester) async {
  final registrar = _Registrar();
  await _open(tester, registrar);
  await _settle(tester);

  final resendAnswer = Completer<Response>();
  registrar.login = () => resendAnswer.future;
  await tester.tap(find.byKey(_resend));
  await tester.pump();

  registrar.validate = _neverAnswers;
  await _confirmPin(tester);
  await _settle(tester);
  return resendAnswer;
}

Future<void> _confirmPin(WidgetTester tester) async {
  await tester.enterText(find.byType(EditableText), '1234');
  await tester.pump();
  await tester.tap(find.byKey(_confirm));
  await tester.pump();
}

void _expectPinStep(WidgetTester tester, String when) {
  for (final button in [_cancel, _resend, _confirm]) {
    expect(
      find.byKey(button),
      findsOneWidget,
      reason: 'the PIN step offers $button $when',
    );
  }
  for (final button in [_cancel, _resend]) {
    expect(
      tester.widget<TextButton>(find.byKey(button)).onPressed,
      isNotNull,
      reason: '$button can be pressed $when',
    );
  }
}

void _expectBackAtPinStep(WidgetTester tester) {
  _expectPinStep(tester, 'after a failed Confirm');
  expect(
    tester.widget<EditableText>(find.byType(EditableText)).controller.text,
    isEmpty,
    reason: 'the PIN is cleared',
  );
}

List<String> _lines(LogsCubit logs) => [
  for (final e in logs.logs) e.loggable.toString(),
];

/// Provides the app log [App.log] writes to and the app's strings, and
/// returns the log.
Future<LogsCubit> _pumpApp(WidgetTester tester) async {
  final logs = LogsCubit();
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EnableLoggingCubit()),
        BlocProvider.value(value: logs),
      ],
      child: MaterialApp(
        navigatorKey: App.navState,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(),
      ),
    ),
  );
  return logs;
}
