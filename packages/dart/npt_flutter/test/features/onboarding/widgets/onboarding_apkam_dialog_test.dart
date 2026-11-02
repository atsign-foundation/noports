import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
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

    testWidgets('when the atServer reports the request denied, then its keys'
        ' leave the keychain and the dialog closes saying it was denied', (
      tester,
    ) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      pending.refuse(
        AtEnrollmentException('The enrollment: e1 is denied'),
        discardingFrom: keychain,
      );
      await _settle(tester);

      expect(
        find.byKey(const Key('denied')),
        findsOneWidget,
        reason: 'the dialog says the request was denied',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(
        dialog.result?.message,
        _strings.enrollRequestDenied,
        reason: 'the dialog closes with the denial',
      );
    });

    testWidgets('when the atServer reports the request expired, then its keys'
        ' leave the keychain and the dialog asks for a new OTP, saying the'
        ' request expired', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      pending.refuse(
        AtEnrollmentException(
          'Enrollment e1 has expired or does not exist: '
          'error:AT0028-enrollment_id: e1 is expired or invalid',
        ),
        discardingFrom: keychain,
      );
      await _settle(tester);

      expect(dialog.closed, isFalse, reason: 'the dialog stays open');
      _expectOtpPrompt(tester);
      expect(
        find.text(_strings.requestExpired),
        findsOneWidget,
        reason: 'the OTP prompt says the request expired',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
    });

    for (final (why, error) in <(String, Exception)>[
      ('the atServer could not be reached', AtTimeoutException('Timed out')),
      (
        'the atServer refused it for another reason',
        AtEnrollmentException(
          'Enrollment e1 was refused for a reason this wait cannot resolve: '
          'error:AT0003-Invalid syntax',
        ),
      ),
    ]) {
      testWidgets('when the wait ends because $why, then the request\'s keys'
          ' stay and the dialog closes with the error, not as denied', (
        tester,
      ) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        final dialog = await _open(tester, pending, keychain);

        pending.refuse(error);
        await _settle(tester);

        expect(
          keychain.entries['@alice']?.pendingEnrollmentIds,
          contains('e1'),
          reason: "the request's pending keys stay in the keychain",
        );
        expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
        expect(dialog.closed, isTrue, reason: 'the dialog closes');
        expect(
          dialog.result?.message,
          isNot(_strings.enrollRequestDenied),
          reason: 'the request is not reported as denied',
        );
        expect(
          dialog.result?.message,
          describeOnboardingError(error, _strings),
          reason: 'the dialog closes with what went wrong',
        );
      });
    }

    for (final (how, error, discards) in <(String, Exception, bool)>[
      (
        'the atServer cannot be reached',
        AtTimeoutException('Timed out'),
        false,
      ),
      (
        'the request is denied',
        AtEnrollmentException('The enrollment: e1 is denied'),
        true,
      ),
    ]) {
      testWidgets('when the wait ends because $how while Cancel is being'
          ' confirmed, then the confirmation closes and the dialog closes'
          ' with what ended the wait', (tester) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        final dialog = await _open(tester, pending, keychain);
        await tester.tap(_cancelButton);
        await _settle(tester);
        expect(
          find.text(_strings.abandonRequestTitle),
          findsOneWidget,
          reason: 'a confirmation asks first',
        );

        pending.refuse(error, discardingFrom: discards ? keychain : null);
        await _settle(tester);
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);

        expect(
          find.text(_strings.abandonRequestTitle),
          findsNothing,
          reason:
              'a wait that ends while Cancel is being confirmed closes the'
              ' confirmation',
        );
        expect(pending.cancels, 0, reason: 'nothing is cancelled');
        expect(dialog.closed, isTrue, reason: 'the dialog closes');
        expect(
          dialog.result?.message,
          discards
              ? _strings.enrollRequestDenied
              : describeOnboardingError(error, _strings),
          reason: 'the dialog closes with what ended the wait',
        );
      });
    }

    testWidgets('when the user presses Cancel, then a confirmation names the'
        ' request and says what abandoning it means, and the wait goes on', (
      tester,
    ) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      await _open(tester, pending, keychain);

      await tester.tap(_cancelButton);
      await _settle(tester);

      expect(
        find.text(_strings.abandonRequestTitle),
        findsOneWidget,
        reason: 'a confirmation asks first',
      );
      expect(
        find.text(_strings.abandonRequestBody('@alice', 'e1')),
        findsOneWidget,
        reason:
            'it names the request, and says trying again needs a new OTP from'
            ' another enrollment',
      );
      expect(pending.cancels, 0, reason: 'nothing is cancelled before a yes');
      expect(
        find.byKey(const Key('activating')),
        findsOneWidget,
        reason: 'the dialog is still waiting',
      );
      expect(keychain.writes, 0, reason: 'the keychain is left as it is');
    });

    for (final (how, decline) in <(String, Future<void> Function(WidgetTester))>[
      (
        'chooses Keep waiting',
        (tester) => tester.tap(find.text(_strings.keepWaiting)),
      ),
      (
        'dismisses the confirmation',
        (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape),
      ),
    ]) {
      testWidgets('when the user $how, then the confirmation closes and the'
          ' wait goes on', (tester) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        await _open(tester, pending, keychain);
        await tester.tap(_cancelButton);
        await _settle(tester);

        await decline(tester);
        await _settle(tester);

        expect(
          find.text(_strings.abandonRequestTitle),
          findsNothing,
          reason: 'the confirmation has closed',
        );
        expect(pending.cancels, 0, reason: 'nothing is cancelled');
        expect(keychain.writes, 0, reason: 'the keychain is left as it is');
        final client = _Client();
        pending.approve(client);
        await _settle(tester);
        expect(
          AtClientMethods.currentClientOrNull(),
          same(client),
          reason: 'the wait went on, and its approval is adopted',
        );
        await tester.pump(const Duration(seconds: 3));
        await _settle(tester);
      });
    }

    testWidgets('when a confirmed Cancel is still removing the keys, then'
        ' Cancel is not offered again', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keysDropped = Completer<void>();
      pending.keysDropped = keysDropped.future;
      await _open(tester, pending, _Keychain());

      await _confirmCancel(tester);

      expect(
        find.byKey(const Key('cancelling')),
        findsOneWidget,
        reason: 'the dialog says the request is being abandoned',
      );
      expect(
        _cancelButton,
        findsNothing,
        reason: 'Cancel is not offered while one is in progress',
      );
      expect(pending.cancels, 1, reason: 'cancel has run once');
      keysDropped.complete();
      await _settle(tester);
    });

    testWidgets('when a confirmed Cancel cannot remove the keys, then the'
        ' dialog says so and keeps them, and Cancel then retries without'
        ' asking again', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending()..cancelFailures = 1;
      final keychain = _Keychain();
      await _open(tester, pending, keychain);

      await _confirmCancel(tester);

      expect(
        find.text(_strings.abandonFailed('e1')),
        findsOneWidget,
        reason: 'the dialog says the request could not be abandoned',
      );
      expect(
        keychain.entries,
        contains('@alice'),
        reason: "the request's keys stay in the keychain",
      );
      expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
      expect(_cancelButton, findsOneWidget, reason: 'Cancel is offered again');

      await tester.tap(_cancelButton);
      await _settle(tester);

      expect(
        pending.cancels,
        2,
        reason: 'choosing Cancel again retries without asking again',
      );
      _expectOtpPrompt(tester);
      expect(
        find.text(_strings.requestAbandoned('e1')),
        findsOneWidget,
        reason: 'the OTP prompt says the request was abandoned',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
    });

    testWidgets('when the user leaves after a Cancel that could not remove the'
        ' keys, then the keys stay and the dialog waits on the request again'
        ' when it next opens', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending()..cancelFailures = 1;
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);
      await _confirmCancel(tester);
      expect(
        find.text(_strings.abandonFailed('e1')),
        findsOneWidget,
        reason: 'the dialog says the request could not be abandoned',
      );

      await tester.tap(_backButton);
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog has closed');
      expect(
        keychain.entries,
        contains('@alice'),
        reason: "the request's keys stay in the keychain",
      );
      expect(keychain.writes, 0, reason: 'nothing is written to the keychain');

      final resumed = _Pending();
      await _open(tester, resumed, keychain);
      expect(resumed.waits, 1, reason: 'the next dialog waits on the request');
    });

    testWidgets('when the approval arrives while Cancel is being confirmed,'
        ' then the confirmation closes, nothing is cancelled and the approved'
        ' client is adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final dialog = await _open(tester, pending, _Keychain());
      await tester.tap(_cancelButton);
      await _settle(tester);
      expect(
        find.text(_strings.abandonRequestTitle),
        findsOneWidget,
        reason: 'a confirmation asks first',
      );

      final client = _Client();
      pending.approve(client);
      await _settle(tester);

      expect(
        find.text(_strings.abandonRequestTitle),
        findsNothing,
        reason: 'the approval closes the confirmation',
      );
      expect(pending.cancels, 0, reason: 'nothing is cancelled');
      expect(
        AtClientMethods.currentClientOrNull(),
        same(client),
        reason: 'the approved client is adopted',
      );
      expect(client.stops, 0, reason: 'the approved client keeps running');
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(
        dialog.result?.status,
        NoPortsOnboardingResultStatus.success,
        reason: 'the dialog closes as approved',
      );
    });

    testWidgets('when the user confirms Cancel, then the wait is cancelled,'
        ' which drops its pending keys, and the dialog then asks for a new OTP'
        ' and tells the user to deny the request in the Authenticator, with'
        ' nothing adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keysDropped = Completer<void>();
      pending.keysDropped = keysDropped.future;
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      await _confirmCancel(tester);
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
        find.text(_strings.requestAbandoned('e1')),
        findsOneWidget,
        reason: 'the OTP prompt tells the user to deny the cancelled request',
      );
      expect(
        keychain.entries,
        isNot(contains('@alice')),
        reason: 'the keys the request left in the keychain are dropped',
      );
      expect(
        keychain.removalsOutsideWriteSection,
        0,
        reason: 'the entry is removed in the write section that read it',
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

    for (final (how, leave) in <(String, Future<void> Function(WidgetTester))>[
      ('chooses Back', (tester) => tester.tap(_backButton)),
      (
        'closes the dialog',
        (tester) async => Navigator.of(App.navState.currentContext!).pop(),
      ),
    ]) {
      testWidgets('when the user $how, then the wait is stopped, not'
          ' cancelled, its pending keys stay and nothing is adopted', (
        tester,
      ) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        final dialog = await _open(tester, pending, keychain);

        await leave(tester);
        await _settle(tester);

        expect(pending.stops, 1, reason: "leaving stops the request's wait");
        expect(pending.cancels, 0, reason: 'leaving does not cancel it');
        expect(dialog.closed, isTrue, reason: 'the dialog has closed');
        expect(
          keychain.entries,
          contains('@alice'),
          reason: "the request's pending keys stay in the keychain",
        );
        expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
        expect(
          AtClientMethods.currentClientOrNull(),
          isNull,
          reason: 'nothing is adopted',
        );
      });
    }

    testWidgets('when Cancel lands after the approval is written but before'
        ' the client opens, then the approval stands and the approved client'
        ' is the one the app uses', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final flows = _Flows(pending);
      final client = _Client();
      flows.onOpen = () async => client;
      final waitEnds = Completer<void>();
      pending.waitEnds = waitEnds.future;
      final dialog = await _open(tester, pending, keychain, flows: flows);

      keychain.entries['@alice'] = _approvedKeys();
      pending.approved = true;
      await _confirmCancel(tester);

      expect(pending.cancels, 1, reason: "Cancel cancels the request's wait");
      expect(
        flows.opens,
        0,
        reason: 'no client opens on the approved keys before the wait has ended',
      );
      waitEnds.complete();
      await _settle(tester);
      expect(flows.opens, 1, reason: 'a client is opened on the approved keys');
      expect(
        AtClientMethods.currentClientOrNull(),
        same(client),
        reason: 'the client opened on the approved keys is adopted',
      );
      expect(
        keychain.writes,
        0,
        reason: 'the approved keys stay as the approval wrote them',
      );
      expect(
        find.text(_strings.requestAbandoned('e1')),
        findsNothing,
        reason: 'the request is not reported as still pending',
      );
      await tester.pump(const Duration(seconds: 3));
      await _settle(tester);
      expect(
        dialog.result?.status,
        NoPortsOnboardingResultStatus.success,
        reason: 'the dialog closes as approved',
      );
    });

    testWidgets('when the user leaves after the approval is written but'
        ' before the client opens, then the wait is stopped, the approved keys'
        ' stay and nothing is adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final flows = _Flows(pending);
      final dialog = await _open(tester, pending, keychain, flows: flows);

      keychain.entries['@alice'] = _approvedKeys();
      pending.approved = true;
      Navigator.of(App.navState.currentContext!).pop();
      await _settle(tester);

      expect(pending.stops, 1, reason: "leaving stops the request's wait");
      expect(pending.cancels, 0, reason: 'leaving does not cancel it');
      expect(dialog.closed, isTrue, reason: 'the dialog has closed');
      expect(flows.opens, 0, reason: 'nothing opens once the dialog is closed');
      expect(
        keychain.writes,
        0,
        reason: 'the approved keys stay as the approval wrote them',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });

    testWidgets('when Cancel lands after the approval is written and the'
        ' approved client cannot be opened, then the dialog closes with the'
        ' error and nothing is adopted', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final flows = _Flows(pending);
      flows.onOpen = () async => throw AtTimeoutException('Timed out');
      final dialog = await _open(tester, pending, keychain, flows: flows);

      keychain.entries['@alice'] = _approvedKeys();
      pending.approved = true;
      await _confirmCancel(tester);
      await _settle(tester);

      expect(flows.opens, 1, reason: 'a client is opened on the approved keys');
      expect(dialog.closed, isTrue, reason: 'the dialog closes');
      expect(dialog.result?.status, NoPortsOnboardingResultStatus.error);
      expect(
        dialog.result?.message,
        _strings.errorAuthenticationTimedOut,
        reason: 'the dialog closes with what went wrong',
      );
      expect(
        keychain.writes,
        0,
        reason: 'the approved keys stay as the approval wrote them',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });

    testWidgets('when the dialog is closed while the approved client opens'
        ' after a Cancel, then that client is stopped and nothing is adopted', (
      tester,
    ) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final flows = _Flows(pending);
      final opening = Completer<AtClient>();
      flows.onOpen = () => opening.future;
      final client = _Client();
      await _open(tester, pending, keychain, flows: flows);

      keychain.entries['@alice'] = _approvedKeys();
      pending.approved = true;
      await _confirmCancel(tester);
      await _settle(tester);
      expect(
        flows.opens,
        1,
        reason: 'a client is opening on the approved keys',
      );
      Navigator.of(App.navState.currentContext!).pop();
      await _settle(tester);
      opening.complete(client);
      await _settle(tester);

      expect(
        client.stops,
        1,
        reason: 'a client that opens after the dialog closed is stopped',
      );
      expect(
        AtClientMethods.currentClientOrNull(),
        isNull,
        reason: 'nothing is adopted',
      );
    });

    for (final (held, arrange) in <(String, void Function(_Keychain))>[
      (
        "another enrollment's live keys",
        (keychain) =>
            keychain.entries['@alice'] = _approvedKeys(enrollmentId: 'e0'),
      ),
      ('no keys', (keychain) => keychain.entries.remove('@alice')),
      (
        'keys it cannot read',
        (keychain) => keychain.readError = StateError('unreadable'),
      ),
    ]) {
      testWidgets('when Cancel lands while the keychain holds $held for the'
          ' atSign, then no client is opened and the dialog asks for a new'
          ' OTP, telling the user to deny the request', (tester) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        final flows = _Flows(pending);
        flows.onOpen = () async => _Client();
        await _open(tester, pending, keychain, flows: flows);

        arrange(keychain);
        await _confirmCancel(tester);
        await _settle(tester);

        expect(flows.opens, 0, reason: 'no client is opened');
        _expectOtpPrompt(tester);
        expect(
          find.text(_strings.requestAbandoned('e1')),
          findsOneWidget,
          reason: 'the OTP prompt tells the user to deny the cancelled request',
        );
        expect(
          keychain.writes,
          0,
          reason: "the keychain's other keys are left alone",
        );
        expect(
          AtClientMethods.currentClientOrNull(),
          isNull,
          reason: 'nothing is adopted',
        );
      });
    }

    testWidgets('when the approval is written and the client then fails to'
        ' open, then the approved keys stay and the dialog closes with the'
        ' error', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final dialog = await _open(tester, pending, keychain);

      keychain.entries['@alice'] = _approvedKeys();
      pending.approved = true;
      pending.refuse(AtTimeoutException('Timed out'));
      await _settle(tester);

      expect(dialog.closed, isTrue, reason: 'the dialog closes');
      expect(dialog.result?.status, NoPortsOnboardingResultStatus.error);
      expect(
        dialog.result?.message,
        _strings.errorAuthenticationTimedOut,
        reason: 'the dialog closes with what went wrong, not as denied',
      );
      expect(
        keychain.writes,
        0,
        reason: 'the approved keys stay as the approval wrote them',
      );
    });

    testWidgets('when a new request is filed for the atSign while a Cancel'
        " the user has since left settles, then the new request's keys are"
        ' left alone', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keysDropped = Completer<void>();
      pending.keysDropped = keysDropped.future;
      final keychain = _Keychain();
      await _open(tester, pending, keychain);

      await _confirmCancel(tester);
      await _settle(tester);
      Navigator.of(App.navState.currentContext!).pop();
      await _settle(tester);
      keychain.entries['@alice'] = AtKeys()..recordEnrollmentSnapshot('e2');
      keysDropped.complete();
      await _settle(tester);

      expect(pending.cancels, 1, reason: "Cancel cancels the request's wait");
      expect(
        keychain.entries['@alice']?.enrollmentIds,
        contains('e2'),
        reason: "the new request's keys are left alone",
      );
      expect(keychain.writes, 0, reason: 'nothing is written to the keychain');
    });
  });

  group('Given the enrollment dialog is looking for a request to resume', () {
    for (final (found, resumes) in <(String, bool)>[
      ('one', true),
      ('none', false),
    ]) {
      testWidgets('when the dialog is closed before the lookup finds $found,'
          ' then any request found is stopped, not cancelled, its keys stay'
          ' and nothing is adopted', (
        tester,
      ) async {
        await _pumpApp(tester);
        final pending = _Pending();
        final keychain = _Keychain();
        final flows = _Flows(pending);
        final lookup = Completer<PendingEnrollment?>();
        flows.resumed = lookup.future;
        final dialog = await _open(
          tester,
          pending,
          keychain,
          flows: flows,
          waiting: false,
        );

        Navigator.of(App.navState.currentContext!).pop();
        await _settle(tester);
        lookup.complete(resumes ? pending : null);
        await _settle(tester);

        expect(
          pending.stops,
          resumes ? 1 : 0,
          reason: 'a request found after the dialog closed is stopped',
        );
        expect(pending.cancels, 0, reason: 'nothing is cancelled');
        expect(pending.waits, 0, reason: 'no wait starts once the dialog closed');
        expect(dialog.closed, isTrue, reason: 'the dialog has closed');
        expect(keychain.writes, 0, reason: 'the keychain is left as it is');
        expect(
          AtClientMethods.currentClientOrNull(),
          isNull,
          reason: 'nothing is adopted',
        );
      });
    }

    testWidgets('when the keychain holds a request this device sent, then the'
        ' dialog waits on it without asking for an OTP, and sends no new'
        ' request', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final flows = _Flows(pending);
      await _open(tester, pending, _Keychain(), flows: flows, waiting: false);

      expect(
        find.byKey(const Key('activating')),
        findsOneWidget,
        reason: 'the dialog shows it is waiting for approval',
      );
      expect(pending.waits, 1, reason: 'the dialog waits on the request found');
      expect(
        find.byKey(const Key('otp')),
        findsNothing,
        reason: 'no OTP is asked for',
      );
      expect(flows.enrolls, 0, reason: 'no new request is sent');
    });
  });

  group('Given the enrollment dialog is sending a request', () {
    testWidgets('when the user leaves before the atServer has answered, then'
        " the request's wait is stopped once it is in, never started, and its"
        ' keys stay', (tester) async {
      await _pumpApp(tester);
      final pending = _Pending();
      final keychain = _Keychain();
      final flows = _Flows(pending)..resumed = Future.value(null);
      final submitted = Completer<PendingEnrollment>();
      flows.submitted = submitted.future;
      final dialog = await _open(
        tester,
        pending,
        keychain,
        flows: flows,
        waiting: false,
      );
      await tester.enterText(find.byType(EditableText), 'ABC123');
      await _settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, _strings.submitOtp));
      await _settle(tester);
      expect(flows.enrolls, 1, reason: 'the request is being sent');

      await tester.tap(_backButton);
      await _settle(tester);
      submitted.complete(pending);
      await _settle(tester);

      expect(pending.stops, 1, reason: "leaving stops the request's wait");
      expect(pending.cancels, 0, reason: 'leaving does not cancel it');
      expect(pending.waits, 0, reason: 'no wait starts once the dialog closed');
      expect(dialog.closed, isTrue, reason: 'the dialog has closed');
      expect(keychain.writes, 0, reason: 'the keychain is left as it is');
    });
  });
}

AppLocalizations get _strings =>
    AppLocalizations.of(App.navState.currentContext!)!;

Finder get _cancelButton => find.widgetWithText(FilledButton, _strings.cancel);

Finder get _backButton => find.widgetWithText(FilledButton, _strings.back);

/// Presses Cancel on the waiting screen and confirms it.
Future<void> _confirmCancel(WidgetTester tester) async {
  await tester.tap(_cancelButton);
  await _settle(tester);
  await tester.tap(find.text(_strings.abandonRequest));
  await _settle(tester);
}

/// A request awaiting a decision the test makes. [stop] and [cancel] end the
/// wait as `PendingEnrollment.stop` and `PendingEnrollment.cancel` do, a
/// cancel ending the wait once [waitEnds] completes, as `client()` does
/// after stopping a client it opened, and returning once [keysDropped]
/// completes; a wait started after either ends at once.
class _Pending extends Fake implements PendingEnrollment {
  final _decision = Completer<AtClient>();
  var _waiting = false;
  var waits = 0;
  var stops = 0;
  var cancels = 0;
  Future<void> waitEnds = Future.value();
  Future<void> keysDropped = Future.value();

  /// How many cancels fail as a keychain that refuses the update makes them.
  var cancelFailures = 0;

  @override
  bool approved = false;

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
  }) {
    if (cancels > 0) return Future.error(_cancelled());
    if (stops > 0) return Future.error(_stopped());
    waits++;
    _waiting = true;
    return _decision.future;
  }

  @override
  Future<void> stop() async {
    stops++;
    if (_waiting && !_decision.isCompleted) {
      _decision.completeError(_stopped());
    }
  }

  @override
  Future<void> cancel() async {
    cancels++;
    if (_waiting && !_decision.isCompleted) {
      unawaited(
        waitEnds.then((_) {
          if (!_decision.isCompleted) _decision.completeError(_cancelled());
        }),
      );
    }
    await keysDropped;
    if (cancelFailures > 0) {
      cancelFailures--;
      throw StateError('the keychain refused the update');
    }
  }

  AtEnrollmentCancelledException _cancelled() => AtEnrollmentCancelledException(
    'the wait for enrollment e1 of @alice was cancelled',
  );

  StoppedException _stopped() => StoppedException(
    'the wait for enrollment e1 of @alice was stopped; the request stays in'
    ' its key store, for resumeEnrollment',
  );

  void approve(AtClient client) => _decision.complete(client);

  /// Ends the wait with [error], first removing the request's pending keys
  /// from [discardingFrom], as `PendingEnrollment` does on a denial or an
  /// expiry.
  void refuse(Object error, {_Keychain? discardingFrom}) {
    discardingFrom?.entries['@alice']?.discardEnrollment(enrollmentId);
    _decision.completeError(error);
  }
}

/// Resumes [pending], as if this device had submitted it before, submits
/// requests, counting the [enrolls], and opens a client with [onOpen],
/// counting the [opens].
class _Flows extends Fake implements AtsignFlows {
  _Flows(this.pending);

  final PendingEnrollment pending;
  Future<AtClient> Function() onOpen = () => Completer<AtClient>().future;
  var opens = 0;
  var enrolls = 0;

  /// What the lookup for a request to resume finds, [pending] by default.
  Future<PendingEnrollment?>? resumed;

  /// What submitting a request returns, [pending] by default.
  Future<PendingEnrollment>? submitted;

  @override
  Future<PendingEnrollment> enroll(
    String atSign, {
    required String otp,
    required String app,
    required String device,
    required Map<String, String> namespaces,
    required WrittenAtKeysIo keys,
    required AtClientPreference preference,
    SigningAlgoType? signingAlgo,
    EnrollmentKeyExchangeMode? keyExchangeMode,
    Duration? apkamKeysExpiry,
    AtLookUpFactory? lookUps,
  }) {
    enrolls++;
    return submitted ?? Future.value(pending);
  }

  @override
  Future<AtClient> open(
    String atSign, {
    required AtKeysIo keys,
    required AtClientPreference preference,
    String? namespace,
    AtClientStorage? storage,
    AtLookUpFactory? lookUps,
    AtServiceFactory? serviceFactory,
    Duration? connectBudget,
  }) {
    opens++;
    return onOpen();
  }

  @override
  Future<PendingEnrollment?> resumeEnrollment(
    String atSign, {
    String? app,
    String? device,
    required WrittenAtKeysIo keys,
    required AtClientPreference preference,
    AtLookUpFactory? lookUps,
  }) => resumed ?? Future.value(pending);
}

/// A keychain holding an entry for @alice with nothing live in it, as a
/// request awaiting a decision leaves it. [writes] counts the updates and
/// removals made through it, [removalsOutsideWriteSection] the removals made
/// outside [writing], and a [readError] is thrown by every read.
class _Keychain extends Fake implements KeychainStorage {
  final entries = <String, AtKeys>{'@alice': _pendingKeys()};
  var writes = 0;
  var removalsOutsideWriteSection = 0;
  var _writeSections = 0;
  Object? readError;

  @override
  Future<AtKeys?> getAtsign(String atSign) async {
    if (readError case final error?) throw error;
    return entries[atSign];
  }

  @override
  Future<T> writing<T>(Future<T> Function() action) async {
    _writeSections++;
    try {
      return await action();
    } finally {
      _writeSections--;
    }
  }

  @override
  Future<void> updateAtKeysInKeychain({
    required String atSign,
    required AtKeys keys,
    void Function(AtKeys existing)? assureUpdate,
    bool requireExisting = false,
  }) async {
    writes++;
    entries[atSign] = keys;
  }

  @override
  Future<void> removeAtsignFromKeychain(String atSign) async {
    if (_writeSections == 0) removalsOutsideWriteSection++;
    writes++;
    entries.remove(atSign);
  }
}

/// What a request awaiting a decision leaves in the keychain: its keypair,
/// filed as pending under enrollment e1.
AtKeys _pendingKeys() => AtKeys.fromJson({
  'version': 1,
  'atsign': '@alice',
  'keys': <Object?>[],
  'enrollments': [
    {
      'enrollmentId': 'e1',
      'appName': 'noports',
      'deviceName': 'testdevice',
      'keys': [
        {
          'keyId': 'auth:rsa2048:1',
          'material': [
            {
              'role': 'privateAuthentication',
              'algorithm': 'rsa2048',
              'createdAt': '2026-01-01T00:00:00.000Z',
              'status': 'pending',
              'bytes': 'cHJpdmF0ZQ==',
            },
          ],
        },
      ],
    },
  ],
});

/// Keys an approval of [enrollmentId] has completed, in the shape an rsa2048
/// request is filed in: the APKAM keypair in the flat fields, and the
/// enrollment's snapshot.
AtKeys _approvedKeys({String enrollmentId = 'e1'}) =>
    AtKeys.legacy(
      apkamPublicKey: 'cHVibGlj',
      apkamPrivateKey: 'cHJpdmF0ZQ==',
      enrollmentId: enrollmentId,
    )..recordEnrollmentSnapshot(
      enrollmentId,
      appName: 'noports',
      deviceName: 'testdevice',
    );

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

/// Opens the dialog on [pending], with its keys in [keychain] and its verbs
/// in [flows], and returns once it is [waiting] for the decision.
Future<_Dialog> _open(
  WidgetTester tester,
  _Pending pending,
  _Keychain keychain, {
  _Flows? flows,
  bool waiting = true,
}) async {
  final dialog = _Dialog();
  unawaited(
    showDialog<NoPortsOnboardingResult>(
      context: App.navState.currentContext!,
      barrierDismissible: false,
      builder: (_) => OnboardingApkamDialog(
        atsign: '@alice'.toAtsign(),
        // ignore: deprecated_member_use
        atClientPreference: AtClientPreference()..hiveStoragePath = 'unused',
        flows: flows ?? _Flows(pending),
        deviceName: () async => 'test device',
        keychain: keychain,
      ),
    ).then((result) {
      dialog.closed = true;
      dialog.result = result;
    }),
  );
  await _settle(tester);
  if (waiting) {
    expect(
      find.byKey(const Key('activating')),
      findsOneWidget,
      reason: 'the dialog is waiting for the decision',
    );
  }
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
