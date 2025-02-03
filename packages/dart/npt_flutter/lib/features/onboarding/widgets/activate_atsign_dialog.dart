import 'dart:convert';

import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/features/onboarding/util/onboarding_util.dart';
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class ActivateAtsignDialog extends StatefulWidget {
  final pinLength = 4;
  final String registrarUrl;
  final String apiKey;
  final String atSign;
  final AtOnboardingConfig config;
  final bool waitForTeapot;
  final NoPortsOnboardingUtil onboardingUtil;
  const ActivateAtsignDialog({
    super.key,
    required this.atSign,
    required this.apiKey,
    required this.config,
    required this.registrarUrl,
    required this.waitForTeapot,
    required this.onboardingUtil,
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
  void initState() {
    super.initState();
    util = ActivateUtil(
      registrarUrl: widget.registrarUrl,
      apiKey: widget.apiKey,
    );
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
          ActivationStatus.activating => Text(strings.activationStatusActivating),
        },
      ),
      content: SizedBox(
        height: 80,
        width: 400,
        child: switch (status) {
          ActivationStatus.preparing || ActivationStatus.activating => const Spinner(),
          ActivationStatus.otpWait => SizedBox(
              height: 80,
              child: Column(
                children: [
                  PinCodeTextField(
                    focusNode: pinFocusNode,
                    appContext: context,
                    length: widget.pinLength,
                    controller: pinController,
                    onChanged: (value) {
                      setState(() {
                        pinController.text = value.toUpperCase();
                      });
                    },
                    // Styling
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
                      )
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
        ActivationStatus.otpWait => [cancelButton, resendPinButton, confirmPinButton],
        // Don't allow the user to cancel activate as this opens up a bunch of
        // edge cases around navigation and onboarding state
        ActivationStatus.activating => [],
      },
    );
  }

  Future<void> _getPinCode() async {
    var res = await util.registrarApiRequest(
      NoPortsActivateApiEndpoints.login,
      {'atsign': widget.atSign},
    );

    if (res.statusCode == 200 && jsonDecode(res.body)["message"] == "Sent Successfully") {
      setState(() {
        status = ActivationStatus.otpWait;
      });
      // pinFocusNode.
      if (!pinFocusNode.hasFocus) {
        pinFocusNode.requestFocus();
      }
    } else {
      if (!mounted) return;
      if (status == ActivationStatus.preparing) {
        Navigator.of(context).pop(AtOnboardingResult.error(message: "@${jsonDecode(res.body)["message"]}"));
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(
            strings.errorOtpRequestFailed,
          ),
        ),
      );
    }
  }

  Widget get cancelButton => TextButton(
        key: const Key("NoPortsActivateCancelButton"),
        child: Text(strings.cancel),
        onPressed: () {
          Navigator.of(context).pop(AtOnboardingResult.cancelled());
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
                // 1. If the atSign is not in teapot, it will (assuming success)
                //    start activating the atSign as if you hit "Activate" in the dashboard
                // 2. It will trigger the email/text OTP
                var (:cramkey, :errorMessage) = await util.verifyActivation(
                  atsign: widget.atSign,
                  otp: pinController.text,
                );

                if (cramkey == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.red,
                      content: Text(
                        strings.errorOtpVerificationFailed,
                      ),
                    ),
                  );
                  setState(() {
                    pinController = TextEditingController(); // controller was disposed, make a new one
                    status = ActivationStatus.otpWait;
                  });
                  return;
                }

                // If the atSign wasn't in teapot when we arrived at this screen,
                // we should wait until the atSign is in teapot
                if (widget.waitForTeapot) {
                  int round = 1;
                  getStatus() async {
                    return (await widget.onboardingUtil.atServerStatus(widget.atSign)).status();
                  }

                  AtSignStatus? atSignStatus = await getStatus();
                  while (atSignStatus != AtSignStatus.teapot) {
                    // 6 * 5 = 30 seconds
                    // 12 * 5 = 60 seconds
                    if (round > 12) {
                      break;
                    }
                    await Future.delayed(const Duration(seconds: 5));
                    round++;
                    atSignStatus = (await getStatus());
                  }

                  // If the Atsign is still not in teapot after the waiting period
                  // Then return an error
                  if (atSignStatus != AtSignStatus.teapot) {
                    if (mounted) {
                      Navigator.of(context).pop(
                        AtOnboardingResult.error(message: strings.errorAuthenticationTimedOut),
                      );
                    }
                    return;
                  }
                }

                // Assuming we got the correct OTP, and we are in teapot,
                // being activation: Generating keys, bootstrapping server, etc.
                // i.e. all the stuff to go from teapot -> activated
                var result = await util.onboardFromCramKey(
                  atsign: widget.atSign,
                  cramkey: cramkey,
                  config: widget.config,
                );

                if (!mounted) return;
                Navigator.of(context).pop(result);
              },
        child: Text(strings.confirm),
      );
}
