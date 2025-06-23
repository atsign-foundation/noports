import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/app.dart';
import 'package:npt_flutter/features/onboarding/util/activate_util.dart';
import 'package:npt_flutter/styles/app_color.dart' show AppColor;
import 'package:npt_flutter/widgets/spinner.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';

class ActivateCramDialog extends StatefulWidget {
  final int cramKeyLength;
  final String atSign;
  final AtOnboardingConfig config;
  const ActivateCramDialog({
    super.key,
    required this.atSign,
    required this.config,
    this.cramKeyLength = 128,
  });

  @override
  State<ActivateCramDialog> createState() => _ActivateCramDialogState();
}

enum ActivationStatus {
  initial, // initial state
  activating, // CRAM received, trying to activate
}

class _ActivateCramDialogState extends State<ActivateCramDialog> {
  late final ActivateUtil util;
  ActivationStatus status = ActivationStatus.initial;
  TextEditingController cramController = TextEditingController();
  FocusNode cramFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    util = ActivateUtil();
  }

  final strings = AppLocalizations.of(App.navState.currentContext!)!;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Center(
        child: switch (status) {
          ActivationStatus.initial => Text(strings.typePasteLicense),
          ActivationStatus.activating =>
            Text(strings.activationStatusActivating),
        },
      ),
      content: SizedBox(
        height: Sizes.p80,
        width: Sizes.p600,
        child: switch (status) {
          ActivationStatus.activating => const Spinner(),
          ActivationStatus.initial => SizedBox(
              height: Sizes.p80,
              child: Column(
                children: [
                  SizedBox(
                    width: Sizes.p600,
                    child: TextField(
                      focusNode: cramFocusNode,
                      maxLength: widget.cramKeyLength,
                      controller: cramController,
                      onChanged: (value) {
                        var normalized = value.trim().toLowerCase();
                        setState(() {
                          cramController.value = TextEditingValue(
                            text: normalized,
                            selection: TextSelection.collapsed(
                              offset: normalized.length,
                            ),
                          );
                        });
                      },
                      onSubmitted: (textChanged) {},
                      cursorColor: AppColor.primaryColor,
                      style: const TextStyle(
                        color: AppColor.onSurfaceColor,
                      ),
                      textCapitalization: TextCapitalization.none,
                      canRequestFocus: true,
                      autofocus: true,
                    ),
                  )
                ],
              ),
            ),
        },
      ),
      actions: switch (status) {
        ActivationStatus.initial => [cancelButton, confirmPinButton],
        // Don't allow the user to cancel activate as this opens up a bunch of
        // edge cases around navigation and onboarding state
        ActivationStatus.activating => [],
      },
    );
  }

  Widget get cancelButton => TextButton(
        key: const Key("NoPortsActivateCancelButton"),
        child: Text(strings.cancel),
        onPressed: () {
          Navigator.of(context).pop(AtOnboardingResult.cancelled());
        },
      );

  Widget get confirmPinButton => TextButton(
        key: const Key("NoPortsActivateConfirmButton"),
        onPressed: cramController.text.length != widget.cramKeyLength
            ? null // disable the button when key isn't complete
            : onSubmit,
        child: Text(strings.confirm),
      );

  void onSubmit() async {
    setState(() {
      status = ActivationStatus.activating;
    });

    var result = await util.onboardFromCramKey(
      atsign: widget.atSign,
      cramkey: cramController.text,
      config: widget.config,
    );

    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}
