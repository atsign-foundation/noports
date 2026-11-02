import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart' hide Response;
import 'package:flutter/material.dart';
import 'package:http/http.dart' show Response;
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../../localization/app_localizations.dart';
import '../../../styles/sizes.dart';

class ActivateAtsignDialog extends StatefulWidget {
  final pinLength = 4;
  final String registrarUrl;
  final String apiKey;
  final Atsign atsign;
  final String rootDomain;
  final bool waitForTeapot;
  final NoPortsOnboardingUtil onboardingUtil;

  /// Talks to the registrar in place of one built from [registrarUrl] and
  /// [apiKey], for tests.
  final ActivateUtil? activateUtil;

  const ActivateAtsignDialog({
    super.key,
    required this.atsign,
    required this.apiKey,
    required this.rootDomain,
    required this.registrarUrl,
    required this.waitForTeapot,
    required this.onboardingUtil,
    this.activateUtil,
  });

  @override
  State<ActivateAtsignDialog> createState() => _ActivateAtsignDialogState();
}

enum ActivationStatus {
  preparing, // contacting the registrar to send an OTP
  otpWait, // Waiting for user to enter OTP
  activating, // OTP received, trying to activate
}

class _ActivateAtsignDialogState extends State<ActivateAtsignDialog> {
  late final ActivateUtil util;
  ActivationStatus status = ActivationStatus.preparing;
  TextEditingController pinController = TextEditingController();
  FocusNode pinFocusNode = FocusNode();

  @override
  void dispose() {
    pinController.dispose();
    pinFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    util =
        widget.activateUtil ??
        ActivateUtil(registrarUrl: widget.registrarUrl, apiKey: widget.apiKey);
    _getPinCode();
  }

  final strings = AppLocalizations.of(App.navState.currentContext!)!;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: switch (status) {
          ActivationStatus.preparing => Text(strings.activationStatusPreparing),
          ActivationStatus.otpWait => Text(strings.activationStatusOtpWait),
          ActivationStatus.activating => Text(
            strings.activationStatusActivating,
          ),
        },
      ),
      content: SizedBox(
        height: Sizes.p80,
        width: Sizes.p400,
        child: switch (status) {
          ActivationStatus.preparing ||
          ActivationStatus.activating => const Spinner(),
          ActivationStatus.otpWait => SizedBox(
            height: Sizes.p80,
            child: Column(
              children: [
                PinCodeTextField(
                  focusNode: pinFocusNode,
                  appContext: context,
                  length: widget.pinLength,
                  controller: pinController,
                  autoDisposeControllers: false,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (_) {
                    setState(() {});
                  },
                  animationType: AnimationType.fade,
                  pinTheme: PinTheme(
                    shape: PinCodeFieldShape.box,
                    borderRadius: BorderRadius.circular(5),
                    fieldHeight: 50,
                    fieldWidth: 40,
                    activeFillColor: Colors.white,
                    inactiveFillColor: Colors.white,
                  ),
                  cursorColor: Colors.black,
                  animationDuration: const Duration(milliseconds: 300),
                  enableActiveFill: true,
                  keyboardType: TextInputType.number,
                  boxShadows: const [
                    BoxShadow(
                      offset: Offset(0, 1),
                      color: Colors.black12,
                      blurRadius: 10,
                    ),
                  ],
                  beforeTextPaste: (text) => true,
                ),
              ],
            ),
          ),
        },
      ),
      actions: switch (status) {
        ActivationStatus.preparing => [cancelButton],
        ActivationStatus.otpWait => [
          cancelButton,
          resendPinButton,
          confirmPinButton,
        ],
        // Don't allow the user to cancel activate as this opens up a bunch of
        // edge cases around navigation and onboarding state
        ActivationStatus.activating => [],
      },
    );
  }

  Future<void> _getPinCode() async {
    final Response res;
    final bool sent;
    try {
      res = await util.registrarApiRequest(NoPortsActivateApiEndpoints.login, {
        'atsign': widget.atsign,
      });
      sent =
          res.statusCode == 200 &&
          jsonDecode(res.body)["message"] == "Sent Successfully";
    } catch (e) {
      App.log(
        'Requesting an activation PIN for ${widget.atsign} failed: '
                '${e.runtimeType}'
            .loggable,
      );
      if (!mounted) return;
      if (!_isOpen) return;
      if (status == ActivationStatus.preparing) {
        Navigator.of(context).pop(
          NoPortsOnboardingResult.error(message: strings.errorOtpRequestFailed),
        );
        return;
      }
      _showPinRequestFailed();
      return;
    }

    if (!mounted) return;
    if (!_isOpen) return;
    if (sent && status == ActivationStatus.activating) return;
    if (sent) {
      setState(() {
        status = ActivationStatus.otpWait;
      });
      // pinFocusNode.
      if (!pinFocusNode.hasFocus) {
        pinFocusNode.requestFocus();
      }
    } else {
      if (status == ActivationStatus.preparing) {
        final apiMessage = registrarMessage(res.body);
        final String userMessage =
            apiMessage == null ||
                apiMessage.toLowerCase().contains('unauthorized')
            ? strings.errorOtpRequestFailed
            : apiMessage;
        Navigator.of(context).pop(
          NoPortsOnboardingResult.error(message: userMessage),
        );
        return;
      }
      _showPinRequestFailed();
    }
  }

  /// Whether this dialog is still open, though another route may cover it. It
  /// stays mounted while it animates closed, so a reply arriving then must not
  /// act on it. Nothing may cover it while it is preparing, since closing it
  /// then pops whichever route is on top.
  bool get _isOpen => ModalRoute.of(context)?.isActive ?? false;

  void _showPinRequestFailed() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red,
        content: Text(strings.errorOtpRequestFailed),
      ),
    );
  }

  /// Shows [message] and returns to the PIN step with the PIN cleared.
  void _returnToPinStep(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(message)),
      );
    setState(() {
      pinController.clear();
      status = ActivationStatus.otpWait;
    });
  }

  Widget get cancelButton => TextButton(
    key: const Key("NoPortsActivateCancelButton"),
    child: Text(strings.cancel),
    onPressed: () {
      // Unfocus the field before closing the dialog
      if (pinFocusNode.hasFocus) {
        pinFocusNode.unfocus();
      }
      Navigator.of(context).pop(NoPortsOnboardingResult.cancelled());
    },
  );

  Widget get resendPinButton => TextButton(
    key: const Key("NoPortsActivateResendButton"),
    onPressed: _getPinCode,
    child: Text(strings.resendPin),
  );

  Widget get confirmPinButton => TextButton(
    key: const Key("NoPortsActivateConfirmButton"),
    onPressed: pinController.text.length < 4
        ? null // disable the button when pin isn't complete
        : () async {
            setState(() {
              status = ActivationStatus.activating;
            });

            // This does two things:
            // 1. If the atsign is not in teapot, it will (assuming success)
            //    start activating the atsign as if you hit "Activate" in the dashboard
            // 2. It will trigger the email/text OTP
            final ({String? cramkey, String? errorMessage}) verified;
            try {
              verified = await util.verifyActivation(
                atsign: widget.atsign,
                otp: pinController.text.toUpperCase(),
              );
            } catch (e) {
              App.log(
                'Verifying the activation PIN for ${widget.atsign} failed: '
                        '${e.runtimeType}'
                    .loggable,
              );
              if (!mounted) return;
              _returnToPinStep(strings.errorOtpVerificationFailed);
              return;
            }
            final (:cramkey, :errorMessage) = verified;

            if (!mounted) return;

            if (cramkey == null) {
              App.log('OTP verification failed: $errorMessage'.loggable);
              _returnToPinStep(
                errorMessage ?? strings.errorOtpVerificationFailed,
              );
              return;
            }

            // If the atsign wasn't in teapot when we arrived at this screen,
            // we should wait until the atsign is in teapot
            if (widget.waitForTeapot) {
              int round = 1;
              getStatus() async {
                return (await widget.onboardingUtil.checkAtServer(
                  widget.atsign,
                )).state;
              }

              AtSignServerState atsignStatus = await getStatus();
              while (atsignStatus != AtSignServerState.notActivated) {
                // 6 * 5 = 30 seconds
                // 12 * 5 = 60 seconds
                if (!mounted || round > 12) {
                  break;
                }
                await Future.delayed(const Duration(seconds: 5));
                round++;
                atsignStatus = (await getStatus());
              }

              // If the Atsign is still not in teapot after the waiting period
              // Then return an error
              if (atsignStatus != AtSignServerState.notActivated) {
                if (mounted) {
                  Navigator.of(context).pop(
                    NoPortsOnboardingResult.error(
                      message: strings.errorAuthenticationTimedOut,
                    ),
                  );
                }
                return;
              }
            }

            // Assuming we got the correct OTP, and we are in teapot,
            // being activation: Generating keys, bootstrapping server, etc.
            // i.e. all the stuff to go from teapot -> activated
            var result = await util.onboardFromCramKey(
              atsign: widget.atsign,
              cramkey: cramkey,
              rootDomain: widget.rootDomain,
              strings: strings,
            );

            if (!mounted) return;
            Navigator.of(context).pop(result);
          },
    child: Text(strings.confirm),
  );
}
