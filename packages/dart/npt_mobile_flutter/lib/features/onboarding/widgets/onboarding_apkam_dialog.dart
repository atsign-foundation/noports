import 'dart:async';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client/at_client.dart';
import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:at_onboarding_flutter/at_onboarding_flutter.dart';
import 'package:npt_mobile_flutter/util/onboarding_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:npt_mobile_flutter/features/onboarding/util/atsign_manager.dart';
import 'package:npt_mobile_flutter/features/onboarding/widgets/enrollment_dialog.dart';
import 'package:npt_mobile_flutter/localization/app_localizations.dart';
import 'package:npt_mobile_flutter/styles/sizes.dart';
import 'package:npt_mobile_flutter/util/constants.dart';
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

class OnboardingApkamDialog extends StatefulWidget {
  const OnboardingApkamDialog({
    required this.atsign,
    required this.atClientPreference,
    super.key,
  });

  final String atsign;
  final AtClientPreference atClientPreference;

  @override
  OnboardingApkamDialogState createState() => OnboardingApkamDialogState();
}

class OnboardingApkamDialogState extends State<OnboardingApkamDialog> {
  String get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;

  static const _kPinLength = 6;

  late OnboardingStatus onboardingStatus;
  late final AtAuthServiceImpl authService;
  late final TextEditingController pinController;
  late final TextEditingController deviceNameController;
  Timer? _statusCheckTimer;

  bool hasExpired = false;

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    authService = AtAuthServiceImpl(atsign, atClientPreference);
    pinController = TextEditingController();
    deviceNameController = TextEditingController();
    init();
  }

  @override
  void dispose() {
    _statusCheckTimer?.cancel();
    pinController.dispose();
    deviceNameController.dispose();
    super.dispose();
  }

  Future<String> getDeviceName() async {
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

  Future<void> _setStateOnStatus(EnrollmentStatus enrollmentStatus) async {
    switch (enrollmentStatus) {
      case EnrollmentStatus.pending:
        setState(() {
          hasExpired = false;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      case EnrollmentStatus.approved:
        await onApproved();
      case EnrollmentStatus.denied:
        await onDenied();
      case EnrollmentStatus.revoked:
        // Enrollment was revoked, allow user to try again
        App.log('Enrollment was revoked. Resetting to OTP entry'.loggable);
        setState(() {
          hasExpired = true;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      case EnrollmentStatus.expired:
        App.log('Original request has expired. Submit again'.loggable);
        setState(() {
          hasExpired = true;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
    }
  }

  Future<void> init() async {
    // Set initial device name
    final deviceName = await getDeviceName();
    deviceNameController.text = deviceName;

    final sentEnrollRequest = await authService.getSentEnrollmentRequest();
    App.log('Sent enroll request: ${sentEnrollRequest?.toJson()}'.loggable);
    if (sentEnrollRequest != null) {
      if (DateTime.now()
              .toUtc()
              .difference(
                DateTime.fromMillisecondsSinceEpoch(
                  sentEnrollRequest.enrollmentSubmissionTimeEpoch,
                ),
              )
              .inHours >=
          48) {
        await _setStateOnStatus(EnrollmentStatus.expired);
      } else {
        // If the request has already been sent, we need to say wait for approval
        setState(() {
          onboardingStatus = OnboardingStatus.pendingApproval;
        });
      }
    }

    // Returns EnrollmentStatus.expired even if no request has been sent
    final status = await authService.getFinalEnrollmentStatus();
    App.log('Final enrollment status: $status'.loggable);

    // If status is revoked, start fresh with OTP entry
    if (status == EnrollmentStatus.revoked) {
      App.log('Enrollment request was revoked, resetting'.loggable);
      setState(() {
        hasExpired = true;
        onboardingStatus = OnboardingStatus.otpRequired;
      });
      return;
    }

    if (status == EnrollmentStatus.expired && sentEnrollRequest == null) {
      setState(() {
        onboardingStatus = OnboardingStatus.otpRequired;
      });
    } else {
      await _setStateOnStatus(status);
    }
  }

  void _startStatusPolling() {
    // Cancel any existing timer
    _statusCheckTimer?.cancel();

    // Check status every 3 seconds while in pending approval
    _statusCheckTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (onboardingStatus != OnboardingStatus.pendingApproval) {
        timer.cancel();
        return;
      }

      try {
        final status = await authService.getFinalEnrollmentStatus();
        App.log('Polling status: $status'.loggable);

        if (status == EnrollmentStatus.approved ||
            status == EnrollmentStatus.denied ||
            status == EnrollmentStatus.revoked) {
          timer.cancel();
          await _setStateOnStatus(status);
        }
      } catch (e) {
        App.log('Error polling status: $e'.loggable);
      }
    });
  }

  Future<void> onApproved() async {
    _statusCheckTimer?.cancel();
    setState(() {
      onboardingStatus = OnboardingStatus.success;
    });

    // Wait a bit to show the success message
    await Future.delayed(const Duration(milliseconds: 2000));

    if (!mounted) return;

    App.log('[APKAM] Starting onboard process for $atsign'.loggable);

    // Now onboard to initialize the atClient with the enrolled keys
    try {
      final onboardingResult = await AtOnboarding.onboard(
        context: context,
        config: AtOnboardingConfig(
          atClientPreference: atClientPreference,
          domain: atClientPreference.rootDomain,
          rootEnvironment: RootEnvironment.Production,
          appAPIKey: await Constants.appAPIKey,
        ),
        atsign: atsign,
      );

      App.log('[APKAM] AtOnboarding.onboard completed successfully'.loggable);

      // AtOnboarding should have already set up all keys in both
      // the keychain and local storage during onboarding
      App.log('[APKAM] Keys should be set up by AtOnboarding'.loggable);

      // CRITICAL: Save atsign to information file so it appears in dropdown
      App.log('[APKAM] Saving atsign information for $atsign'.loggable);
      final saveResult = await saveAtsignInformation(
        AtsignInformation(
          atSign: atsign,
          rootDomain: atClientPreference.rootDomain,
        ),
      );
      App.log('[APKAM] Save atsign information result: $saveResult'.loggable);

      App.log(
        '[APKAM] Returning result with status: ${onboardingResult.status}'
            .loggable,
      );

      if (mounted) {
        Navigator.of(context).pop(onboardingResult);
      }
    } catch (e) {
      App.log('[ERROR] APKAM onboarding error: $e'.loggable);
      if (mounted) {
        Navigator.of(context).pop(
          AtOnboardingResult.error(
            message: 'Failed to complete onboarding: $e',
          ),
        );
      }
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
      ).pop(AtOnboardingResult.error(message: strings.enrollRequestDenied));
    }
  }

  Future<void> otpSubmit(String otp) async {
    setState(() {
      onboardingStatus = OnboardingStatus.validatingOtp;
      hasExpired = false;
    });

    final onboardingService = OnboardingService.getInstance();

    // Device name cannot contain spaces or special characters
    final regExp = RegExp(r'[^a-zA-Z0-9]');
    var deviceName = deviceNameController.text.trim().replaceAll(regExp, '');

    // Fallback to getting device name if controller is empty
    if (deviceName.isEmpty) {
      deviceName = (await getDeviceName()).replaceAll(regExp, '');
    }

    App.log('Device Name: $deviceName'.loggable);

    final enrollmentRequest = EnrollmentRequest(
      appName: Constants.namespace,
      deviceName: deviceName,
      otp: otp,
      namespaces: {Constants.namespace: 'rw', "sshnp": 'rw', 'sshrvd': 'rw'},
    );

    App.log('About to enroll with $enrollmentRequest'.loggable);

    try {
      final enrollResponse = await onboardingService.enroll(
        atsign: atsign,
        appName: Constants.namespace,
        deviceName: deviceName,
        otp: otp,
        atClientPreference: widget.atClientPreference,
      );
      App.log('Enroll response: $enrollResponse'.loggable);

      // Check if enrollment failed
      if (enrollResponse.status == AtOnboardingResultStatus.error) {
        final errorMsg = enrollResponse.message ?? 'Unknown error';
        App.log('Enrollment returned error: $errorMsg'.loggable);

        if (mounted) {
          // Check if it's an authentication/OTP error
          if (errorMsg.contains('failed to authenticate') ||
              errorMsg.contains('Invalid OTP') ||
              errorMsg.contains('AT0022')) {
            setState(() {
              hasExpired = true;
              onboardingStatus = OnboardingStatus.otpRequired;
            });
          } else {
            Navigator.of(
              context,
            ).pop(AtOnboardingResult.error(message: errorMsg));
          }
        }
        return;
      }
    } on AtException catch (e, st) {
      App.log('AtException - Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);
      if (mounted) {
        setState(() {
          hasExpired = true;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
      }
      return;
    } catch (e, st) {
      App.log('Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);

      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        // Check for specific error codes
        if (e.toString().contains('AT0022') ||
            e.toString().contains('Invalid OTP') ||
            e.toString().contains('failed to authenticate')) {
          App.log('Invalid or expired OTP'.loggable);
          setState(() {
            hasExpired = true;
            onboardingStatus = OnboardingStatus.otpRequired;
          });
        } else {
          App.log('Unknown error during enrollment: $e'.loggable);
          Navigator.of(
            context,
          ).pop(AtOnboardingResult.error(message: strings.unknownError));
        }
      }
      return;
    }

    setState(() {
      onboardingStatus = OnboardingStatus.pendingApproval;
    });

    // Start periodic status checking
    _startStatusPolling();

    // Wait for approval status to change
    final finalStatus = await authService.getFinalEnrollmentStatus();
    App.log('Final enrollment status: $finalStatus'.loggable);

    // Only update status if it's actually approved or denied, not expired
    if (finalStatus == EnrollmentStatus.approved ||
        finalStatus == EnrollmentStatus.denied) {
      await _setStateOnStatus(finalStatus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

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
          OnboardingStatus.validatingOtp => SingleChildScrollView(
            key: const Key('otp'),
            child: Column(
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
                gapH16,
                Text(
                  'Device Name',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                gapH8,
                SizedBox(
                  height: 56,
                  child: TextField(
                    controller: deviceNameController,
                    style: const TextStyle(fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Enter device name',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.grey),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: Theme.of(context).primaryColor,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                if (hasExpired) ...[
                  gapH4,
                  Text(
                    strings.requestExpired,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                gapH24,
                isMobile
                    ? Column(
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            // Styling
                            animationType: AnimationType.fade,
                            pinTheme: PinTheme(
                              shape: PinCodeFieldShape.box,
                              borderRadius: BorderRadius.circular(5),
                              fieldWidth: 36,
                              fieldHeight: 45,
                              activeFillColor: Colors.white,
                              inactiveFillColor: const Color(0xFFF3F3F3),
                              disabledColor: Colors.blue,
                              inactiveColor: const Color(0xFF747474),
                              selectedFillColor: Colors.white,
                              selectedColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              fieldOuterPadding: const EdgeInsets.symmetric(
                                horizontal: Sizes.p1,
                              ),
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
                            animation: Listenable.merge([
                              pinController,
                              deviceNameController,
                            ]),
                            builder: (context, _) {
                              final hasDeviceName = deviceNameController.text
                                  .trim()
                                  .isNotEmpty;
                              final hasPin =
                                  pinController.text.length == _kPinLength;
                              final isValidating =
                                  onboardingStatus ==
                                  OnboardingStatus.validatingOtp;

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
                                    hasDeviceName && hasPin && !isValidating
                                    ? () async {
                                        await otpSubmit(pinController.text);
                                      }
                                    : null,
                                child: isValidating
                                    ? const CircularProgressIndicator()
                                    : Text(strings.submitOtp),
                              );
                            },
                          ),
                          gapH8,
                          PopButton(
                            onboardingStatus: onboardingStatus,
                            context: context,
                            title: strings.back,
                          ),
                        ],
                      )
                    : IntrinsicHeight(
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
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    // Styling
                                    animationType: AnimationType.fade,
                                    pinTheme: PinTheme(
                                      shape: PinCodeFieldShape.box,
                                      borderRadius: BorderRadius.circular(5),
                                      activeFillColor: Colors.white,
                                      inactiveFillColor: const Color(
                                        0xFFF3F3F3,
                                      ),
                                      disabledColor: Colors.blue,
                                      inactiveColor: const Color(0xFF747474),
                                      selectedFillColor: Colors.white,
                                      selectedColor: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fieldOuterPadding: const EdgeInsets.all(
                                        Sizes.p2,
                                      ),
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
                                    animation: Listenable.merge([
                                      pinController,
                                      deviceNameController,
                                    ]),
                                    builder: (context, _) {
                                      final hasDeviceName = deviceNameController
                                          .text
                                          .trim()
                                          .isNotEmpty;
                                      final hasPin =
                                          pinController.text.length ==
                                          _kPinLength;
                                      final isValidating =
                                          onboardingStatus ==
                                          OnboardingStatus.validatingOtp;

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
                                            hasDeviceName &&
                                                hasPin &&
                                                !isValidating
                                            ? () async {
                                                await otpSubmit(
                                                  pinController.text,
                                                );
                                              }
                                            : null,
                                        child: isValidating
                                            ? const CircularProgressIndicator()
                                            : Text(strings.submitOtp),
                                      );
                                    },
                                  ),
                                  gapH8,
                                  PopButton(
                                    onboardingStatus: onboardingStatus,
                                    context: context,
                                    title: strings.back,
                                  ),
                                ],
                              ),
                            ),
                            if (!isMobile)
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
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                    )
                  : Row(
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
                            child: Image.asset(
                              Constants.authenticatorApprovalMockup,
                            ),
                          ),
                        ),
                      ],
                    ),
              gapH24,
              SizedBox(
                width: isMobile ? double.infinity : 200,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    textStyle: const TextStyle(fontSize: Sizes.p18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: Sizes.p32,
                      vertical: Sizes.p20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Sizes.p8),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      hasExpired = true;
                      onboardingStatus = OnboardingStatus.otpRequired;
                    });
                  },
                  child: Text(strings.back),
                ),
              ),
            ],
          ),
          OnboardingStatus.success => Padding(
            key: const Key('success'),
            padding: const EdgeInsets.all(Sizes.p16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check,
                      color: Colors.green,
                      size: Sizes.p32,
                    ),
                    gapW8,
                    Flexible(
                      child: Text(
                        strings.enrollApproved,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                gapH24,
                PopButton(
                  onboardingStatus: onboardingStatus,
                  context: context,
                  title: strings.done,
                ),
              ],
            ),
          ),
          OnboardingStatus.denied => Padding(
            key: const Key('denied'),
            padding: const EdgeInsets.all(Sizes.p16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.close, color: Colors.red, size: Sizes.p32),
                    gapW8,
                    Flexible(
                      child: Text(
                        strings.enrollDenied,
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
                gapH24,
                PopButton(
                  onboardingStatus: onboardingStatus,
                  context: context,
                  title: strings.done,
                ),
              ],
            ),
          ),
        },
      ),
    );
  }
}

class PopButton extends StatelessWidget {
  const PopButton({
    super.key,
    required this.onboardingStatus,
    required this.context,
    required this.title,
  });

  final OnboardingStatus onboardingStatus;
  final BuildContext context;
  final String title;
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
      onPressed: onboardingStatus != OnboardingStatus.pendingApproval
          ? () {
              Navigator.of(context).pop();
            }
          : null,
      child: Text(title),
    );
  }
}
