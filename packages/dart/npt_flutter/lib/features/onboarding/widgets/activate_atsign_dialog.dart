import 'dart:convert';

import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:at_server_status/at_server_status.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
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
  final AtClientPreference atClientPreference;
  final bool waitForTeapot;
  final NoPortsOnboardingUtil onboardingUtil;
  const ActivateAtsignDialog({
    super.key,
    required this.atsign,
    required this.apiKey,
    required this.atClientPreference,
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
    var res = await util.registrarApiRequest(
      NoPortsActivateApiEndpoints.login,
      {'atsign': widget.atsign},
    );

    if (res.statusCode == 200 &&
        jsonDecode(res.body)["message"] == "Sent Successfully") {
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
        Navigator.of(context).pop(
          NoPortsOnboardingResult.error(
            message: "@${jsonDecode(res.body)["message"]}",
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red,
          content: Text(strings.errorOtpRequestFailed),
        ),
      );
    }
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
            var (:cramkey, :errorMessage) = await util.verifyActivation(
              atsign: widget.atsign,
              otp: pinController.text.toUpperCase(),
              strings: strings,
            );

            if (cramkey == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.red,
                  content: Text(strings.errorOtpVerificationFailed),
                ),
              );
              setState(() {
                pinController =
                    TextEditingController(); // controller was disposed, make a new one
                pinFocusNode =
                    FocusNode(); // focus node was disposed, make a new one
                status = ActivationStatus.otpWait;
              });
              return;
            }

            // If the atsign wasn't in teapot when we arrived at this screen,
            // we should wait until the atsign is in teapot
            if (widget.waitForTeapot) {
              int round = 1;
              getStatus() async {
                return (await widget.onboardingUtil.atServerStatus(
                  widget.atsign,
                )).status();
              }

              AtSignStatus? atsignStatus = await getStatus();
              while (atsignStatus != AtSignStatus.teapot) {
                // 6 * 5 = 30 seconds
                // 12 * 5 = 60 seconds
                if (round > 12) {
                  break;
                }
                await Future.delayed(const Duration(seconds: 5));
                round++;
                atsignStatus = (await getStatus());
              }

              // If the Atsign is still not in teapot after the waiting period
              // Then return an error
              if (atsignStatus != AtSignStatus.teapot) {
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
              atClientPreference: widget.atClientPreference,
              strings: strings,
            );

            if (!mounted) return;
            Navigator.of(context).pop(result);
          },
    child: Text(strings.confirm),
  );
}
