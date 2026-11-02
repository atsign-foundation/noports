import 'dart:async';
import 'dart:io';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_error.dart';
import 'package:npt_flutter/features/onboarding/widgets/enrollment_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/at_client_methods.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../app.dart';

enum OnboardingStatus {
  preparing,
  otpRequired,
  validatingOtp,
  pendingApproval,
  success,
  denied,
}

/// Enrolls this device with [atsign] by quoting an OTP, waits for a manager
/// to approve the request, and adopts the client the approval opens.
class OnboardingApkamDialog extends StatefulWidget {
  const OnboardingApkamDialog({
    required this.atsign,
    required this.atClientPreference,
    this.flows = const AtsignFlows(),
    this.deviceName = platformDeviceName,
    this.keychain,
    super.key,
  });

  final Atsign atsign;
  final AtClientPreference atClientPreference;

  /// The verbs that submit and resume the request; a test stands in for them.
  final AtsignFlows flows;

  /// This device's name as the platform reports it; a test stands in for it.
  final Future<String> Function() deviceName;

  /// The keychain the request's keys are filed in, the platform's by default;
  /// a test stands in for it.
  final KeychainStorage? keychain;

  @override
  OnboardingApkamDialogState createState() => OnboardingApkamDialogState();
}

class OnboardingApkamDialogState extends State<OnboardingApkamDialog> {
  Atsign get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;
  late final KeychainStorage _keychain = widget.keychain ?? KeychainStorage();

  static const _kPinLength = 6;
  static const _kApprovalRetryInterval = Duration(seconds: 10);

  late OnboardingStatus onboardingStatus;
  late final TextEditingController pinController;

  String? _enrollmentError;

  /// Why the request this device waited on is over, shown with the OTP
  /// prompt when a new request is the way on.
  String? _requestOver;

  /// The enrollment being waited on, while one is.
  PendingEnrollment? _pending;

  /// The cancel of the wait in flight, once one is asked for.
  Future<void>? _cancelling;

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    pinController = TextEditingController();
    init();
  }

  @override
  void dispose() {
    final pending = _pending;
    if (pending != null) unawaited(_stop(pending));
    pinController.dispose();
    super.dispose();
  }

  /// Stops the wait on [pending] and keeps the request, so the next sign-in
  /// waits on it again.
  Future<void> _stop(PendingEnrollment pending) async {
    try {
      await pending.stop();
    } catch (e) {
      App.log(
        'Could not stop the wait for enrollment ${pending.enrollmentId}: $e'
            .loggable,
      );
    }
  }

  /// The device name an enrollment is submitted under: the device's own name
  /// with anything but letters and digits removed, since the atServer takes
  /// no spaces or special characters. Deterministic, so a restart can find
  /// the enrollment it submitted.
  Future<String> _enrollmentDeviceName() async {
    final regExp = RegExp(r'[^a-zA-Z0-9]');
    return (await widget.deviceName()).replaceAll(regExp, '');
  }

  /// Picks up an enrollment this device submitted and never completed, whose
  /// keys are still in the keychain, and waits for it; otherwise asks for an
  /// OTP.
  Future<void> init() async {
    PendingEnrollment? pending;
    try {
      pending = await widget.flows.resumeEnrollment(
        atsign,
        app: Constants.namespace,
        device: await _enrollmentDeviceName(),
        keys: KeychainAtKeysIo(keychainStorage: _keychain),
        preference: atClientPreference,
      );
    } catch (e) {
      App.log('No enrollment to resume for $atsign: $e'.loggable);
    }
    App.log('Pending enroll request: ${pending?.enrollmentId}'.loggable);

    if (pending == null) {
      if (!mounted) return;
      setState(() {
        onboardingStatus = OnboardingStatus.otpRequired;
      });
      return;
    }

    await _waitForApprovalAndFinish(pending);
  }

  Future<void> onApproved() async {
    setState(() {
      onboardingStatus = OnboardingStatus.success;
    });
    // Wait for a bit to show the success message
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.of(
        context,
      ).pop(NoPortsOnboardingResult.success(atsign: atsign.toAtsign()));
    }
  }

  Future<void> onDenied() async {
    setState(() {
      onboardingStatus = OnboardingStatus.denied;
    });
    // Wait for a bit to show the error message
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      final strings = AppLocalizations.of(context)!;
      Navigator.of(
        context,
      ).pop(NoPortsOnboardingResult.error(message: strings.enrollRequestDenied));
    }
  }

  /// Asks for a new OTP, with [reason] saying why the request this device
  /// waited on is over.
  void _askForNewOtp(String? reason) {
    if (!mounted) return;
    setState(() {
      _requestOver = reason;
      pinController.clear();
      onboardingStatus = OnboardingStatus.otpRequired;
    });
  }

  /// Cancels the wait on [_pending], if there is one; [_afterCancel] settles
  /// how it ends.
  void _cancelWait() {
    final pending = _pending;
    if (pending == null) return;
    _pending = null;
    App.log(
      'Cancelling the wait for enrollment ${pending.enrollmentId}'.loggable,
    );
    _cancelling = pending.cancel();
  }

  /// Settles a wait [_cancelWait] ended, once the cancel has dropped the
  /// request's pending keys. An approval written before the cancel stands,
  /// and opens the app's client while the dialog is open. Otherwise what is
  /// left of the request's keychain entry is dropped, and the dialog asks for
  /// a new OTP, saying the request is still pending and should be denied.
  Future<void> _afterCancel(PendingEnrollment pending) async {
    await _cancelling;
    if (pending.approved) {
      if (mounted) await _openApproved();
      return;
    }
    await _discard(pending);
    if (!mounted) return;
    _askForNewOtp(AppLocalizations.of(context)!.cancelledRequestStillPending);
  }

  /// Opens the app's client on the keys an approval wrote before its wait was
  /// cancelled, and adopts it unless the dialog has closed meanwhile.
  Future<void> _openApproved() async {
    final AtClient client;
    try {
      client = await widget.flows.open(
        atsign,
        keys: KeychainAtKeysIo(keychainStorage: _keychain),
        preference: atClientPreference,
      );
    } catch (e, st) {
      App.log('Error opening the approved enrollment: $e'.loggable);
      App.log(st.toString().loggable);
      _closeWithError(e);
      return;
    }
    if (!mounted) {
      await client.stop();
      return;
    }
    AtClientMethods.adopt(client);
    await onApproved();
  }

  /// Closes the dialog with what [error] says went wrong.
  void _closeWithError(Object error) {
    if (!mounted) return;
    Navigator.of(context).pop(
      NoPortsOnboardingResult.error(
        message: describeOnboardingError(error, AppLocalizations.of(context)!),
      ),
    );
  }

  /// Waits for [pending] to be approved, then opens the app's client on the
  /// keys the approval completed. On any other end (denial, expiry,
  /// revocation, timeout, error) what the enrollment left in the keychain is
  /// dropped, so the app doesn't keep resuming a dead enrollment, unless the
  /// approval was written before the end, when the keys stay and the dialog
  /// closes with the error; a cancelled wait is settled by [_afterCancel],
  /// and a wait stopped by leaving the dialog keeps the request.
  Future<void> _waitForApprovalAndFinish(PendingEnrollment pending) async {
    if (!mounted) {
      await _stop(pending);
      return;
    }
    _pending = pending;
    setState(() {
      onboardingStatus = OnboardingStatus.pendingApproval;
    });

    try {
      await AtClientMethods.stopCurrentClient();
      final client = await pending.client(
        atClientPreference,
        retryInterval: _kApprovalRetryInterval,
        storage: await storageOrDefault(atsign, atClientPreference),
      );
      _pending = null;
      AtClientMethods.adopt(client);
      await onApproved();
    } on AtEnrollmentCancelledException {
      await _afterCancel(pending);
    } on StoppedException {
      App.log(
        'Stopped the wait for enrollment ${pending.enrollmentId}; the request '
                'stays for the next sign-in'
            .loggable,
      );
    } catch (e, st) {
      App.log('Error waiting for enrollment approval: $e'.loggable);
      App.log(st.toString().loggable);
      _pending = null;
      if (pending.approved) {
        _closeWithError(e);
        return;
      }
      await _discard(pending);
      if (!mounted) return;
      final strings = AppLocalizations.of(context)!;
      if (isEnrollmentExpired(e)) {
        _askForNewOtp(strings.requestExpired);
      } else if (isEnrollmentRevoked(e)) {
        _askForNewOtp(strings.errorEnrollmentRevoked);
      } else {
        await onDenied();
      }
    }
  }

  /// Drops what [pending] left in the keychain: just this enrollment's
  /// material when the entry holds a credential, otherwise the whole entry,
  /// unless it holds another request filed meanwhile. The read and the write
  /// are one step under the keychain's write lock.
  Future<void> _discard(PendingEnrollment pending) async {
    final keychain = KeychainAtKeysIo(keychainStorage: _keychain);
    try {
      await _keychain.writing(() async {
        final keys = await keychain.read(atsign);
        if (keys.holdsAuthenticationMaterial) {
          await keychain.update(atsign, (keys) {
            keys.discardEnrollment(pending.enrollmentId);
            return true;
          });
        } else if (keys.enrollmentIds.every(
          (id) => id == pending.enrollmentId,
        )) {
          await _keychain.removeAtsignFromKeychain(atsign);
        }
      });
    } catch (e) {
      App.log('Could not drop enrollment ${pending.enrollmentId}: $e'.loggable);
    }
  }

  Future<void> otpSubmit(String otp) async {
    setState(() {
      onboardingStatus = OnboardingStatus.validatingOtp;
      _enrollmentError = null;
      _requestOver = null;
    });

    final deviceName = await _enrollmentDeviceName();
    App.log('Device Name: $deviceName'.loggable);

    try {
      final pending = await widget.flows.enroll(
        atsign,
        otp: otp,
        app: Constants.namespace,
        device: deviceName,
        namespaces: {Constants.namespace: 'rw', "sshnp": 'rw', 'sshrvd': 'rw'},
        keys: KeychainAtKeysIo(keychainStorage: _keychain),
        preference: atClientPreference,
      );
      App.log('Enrollment ${pending.enrollmentId} submitted'.loggable);
      await _waitForApprovalAndFinish(pending);
    } on AtException catch (e, st) {
      App.log('AtException - Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);
      if (mounted) {
        setState(() {
          _enrollmentError = e.message;
          pinController.clear();
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      }
    } catch (e, st) {
      App.log('Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);

      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        final String message = e.toString().contains('AT0022')
            ? strings.invalidOtp
            : describeOnboardingError(e, strings);
        setState(() {
          _enrollmentError = message;
          pinController.clear();
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return EnrollmentDialog(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        child: switch (onboardingStatus) {
          OnboardingStatus.preparing => const CircularProgressIndicator(
            key: Key('preparing'),
          ),
          OnboardingStatus.otpRequired ||
          OnboardingStatus.validatingOtp => Column(
            key: const Key('otp'),
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                strings.enterOtp,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: Colors.black),
              ),
              gapH4,
              Text(
                strings.findOtp,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (_requestOver != null) ...[
                gapH4,
                Text(_requestOver!, style: const TextStyle(color: Colors.red)),
              ],
              if (_enrollmentError != null) ...[
                gapH4,
                Text(
                  _enrollmentError!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              gapH24,
              IntrinsicHeight(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: Sizes.p280,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PinCodeTextField(
                            autoDisposeControllers: false,
                            appContext: context,
                            length: _kPinLength,
                            controller: pinController,
                            autoFocus: true,
                            textCapitalization: TextCapitalization.characters,
                            // Styling
                            animationType: AnimationType.fade,
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(5),
                              activeFillColor: Colors.white,
                              inactiveFillColor: const Color(0xFFF3F3F3),
                              disabledColor: Colors.blue,
                              inactiveColor: const Color(0xFF747474),
                              selectedFillColor: Colors.white,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              fieldOuterPadding: const EdgeInsets.all(Sizes.p2),
                            ),
                            cursorColor: Colors.black,
                            animationDuration: const Duration(
                              milliseconds: 300,
                            ),
                            enableActiveFill: true,
                            keyboardType: TextInputType.text,
                            beforeTextPaste: (text) => true,
                          ),
                          gapH8,
                          AnimatedBuilder(
                            animation: pinController,
                            builder: (context, _) {
                              return FilledButton(
                                style: FilledButton.styleFrom(
                                  textStyle: const TextStyle(
                                    fontSize: Sizes.p18,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: Sizes.p32,
                                    vertical: Sizes.p20,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      Sizes.p8,
                                    ),
                                  ),
                                ),
                                onPressed:
                                    pinController.text.length == _kPinLength &&
                                        onboardingStatus !=
                                            OnboardingStatus.validatingOtp
                                    ? () async {
                                        await otpSubmit(pinController.text);
                                      }
                                    : null,
                                child:
                                    onboardingStatus ==
                                        OnboardingStatus.validatingOtp
                                    ? const CircularProgressIndicator()
                                    : Text(strings.submitOtp),
                              );
                            },
                          ),
                          gapH8,
                          PopButton(
                            context: context,
                            title: strings.back,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Transform.translate(
                        offset: const Offset(Sizes.p32, 0),
                        child: Image.asset(
                          Constants.authenticatorMockup,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          OnboardingStatus.pendingApproval => Column(
            key: const Key('activating'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  // This is a little hacky to get the white background.
                  // If this is a problem, we can rethink the EnrollmentDialog widget.
                  Positioned.fill(
                    child: Transform.scale(
                      scaleX: 1.15,
                      scaleY: 2.8,
                      child: Container(color: Colors.white),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          strings.waitingForApproval,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      gapW8,
                      const CircularProgressIndicator(),
                    ],
                  ),
                ],
              ),
              gapH56,
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Just to slightly offset from the top
                        gapH12,
                        Text(
                          strings.whereToAccept,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          strings.whereToAcceptDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Transform.translate(
                      offset: const Offset(Sizes.p18, 0),
                      child: Image.asset(Constants.authenticatorApprovalMockup),
                    ),
                  ),
                ],
              ),
              gapH24,
              Row(
                children: [
                  PopButton(context: context, title: strings.back),
                  gapW8,
                  PopButton(
                    context: context,
                    title: strings.cancel,
                    onPressed: _cancelWait,
                  ),
                ],
              ),
            ],
          ),
          OnboardingStatus.success => Column(
            children: [
              Row(
                key: const Key('success'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, color: Colors.green, size: Sizes.p32),
                  gapW4,
                  Text(
                    strings.enrollApproved,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              gapW8,
              PopButton(
                context: context,
                title: strings.done,
              ),
            ],
          ),
          OnboardingStatus.denied => Column(
            children: [
              Row(
                key: const Key('denied'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close, color: Colors.red, size: Sizes.p32),
                  gapW4,
                  Text(
                    strings.enrollDenied,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              gapW8,
              PopButton(
                context: context,
                title: strings.done,
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// This device's name as the platform reports it.
Future<String> platformDeviceName() async {
  final deviceInfo = DeviceInfoPlugin();

  if (Platform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    return '${androidInfo.manufacturer} ${androidInfo.model}';
  } else if (Platform.isIOS) {
    final iosInfo = await deviceInfo.iosInfo;
    return '${iosInfo.name} (${iosInfo.model})';
  } else if (Platform.isMacOS) {
    final macInfo = await deviceInfo.macOsInfo;
    return macInfo.computerName;
  } else if (Platform.isWindows) {
    final windowsInfo = await deviceInfo.windowsInfo;
    return windowsInfo.computerName;
  } else if (Platform.isLinux) {
    final linuxInfo = await deviceInfo.linuxInfo;
    return linuxInfo.name;
  } else {
    return 'Unknown Device';
  }
}

class PopButton extends StatelessWidget {
  const PopButton({
    super.key,
    required this.context,
    required this.title,
    this.onPressed,
  });

  final BuildContext context;
  final String title;

  /// What the button does instead of popping.
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(fontSize: Sizes.p18),
        padding: const EdgeInsets.symmetric(
          horizontal: Sizes.p32,
          vertical: Sizes.p20,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Sizes.p8),
        ),
      ),
      onPressed: onPressed ?? () => Navigator.of(context).pop(),
      child: Text(title),
    );
  }
}
