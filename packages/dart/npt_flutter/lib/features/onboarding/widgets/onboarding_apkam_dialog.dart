import 'dart:developer';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:npt_flutter/features/onboarding/model/onboarding_result.dart';
import 'package:npt_flutter/features/onboarding/util/at_client_activation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/widgets/enrollment_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
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

class OnboardingApkamDialog extends StatefulWidget {
  const OnboardingApkamDialog({
    required this.atsign,
    required this.atClientPreference,
    super.key,
  });

  final Atsign atsign;
  final AtClientPreference atClientPreference;

  @override
  OnboardingApkamDialogState createState() => OnboardingApkamDialogState();
}

class OnboardingApkamDialogState extends State<OnboardingApkamDialog> {
  String get atsign => widget.atsign;
  AtClientPreference get atClientPreference => widget.atClientPreference;

  static const _kPinLength = 6;

  late OnboardingStatus onboardingStatus;
  late final FlutterEnrollmentService enrollmentService;
  late final TextEditingController pinController;

  bool hasExpired = false;

  @override
  void initState() {
    super.initState();
    onboardingStatus = OnboardingStatus.preparing;
    enrollmentService = FlutterEnrollmentService();
    pinController = TextEditingController();
    init();
  }

  @override
  void dispose() {
    pinController.dispose();
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
        throw UnimplementedError();
      case EnrollmentStatus.expired:
        App.log('Original request has expired. Submit again'.loggable);
        setState(() {
          hasExpired = true;
          onboardingStatus = OnboardingStatus.otpRequired;
        });
    }
  }

  Future<void> init() async {
    final EnrollmentData? sentEnrollRequest = await KeychainStorage()
        .readEnrollmentData(atsign);
    App.log('Sent enroll request: ${sentEnrollRequest?.toJson()}'.loggable);

    if (sentEnrollRequest == null) {
      setState(() {
        onboardingStatus = OnboardingStatus.otpRequired;
      });
      return;
    }

    // enrollmentSubmissionTimeEpoch is written in microseconds by
    // FlutterEnrollmentService.enroll
    final submittedAt = DateTime.fromMicrosecondsSinceEpoch(
      sentEnrollRequest.enrollmentSubmissionTimeEpoch,
      isUtc: true,
    );
    if (DateTime.now().toUtc().difference(submittedAt).inHours >= 48) {
      await _setStateOnStatus(EnrollmentStatus.expired);
      return;
    }

    // A request is already outstanding, so wait for the approver to act on it
    setState(() {
      onboardingStatus = OnboardingStatus.pendingApproval;
    });
    log('Awaiting approval for ${sentEnrollRequest.enrollmentId}');
    await _awaitApproval(
      AtEnrollmentResponse(
        sentEnrollRequest.enrollmentId,
        EnrollmentStatus.pending,
      )..atAuthKeys = sentEnrollRequest.atAuthKeys,
    );
  }

  Future<void> _awaitApproval(AtEnrollmentResponse response) async {
    try {
      await enrollmentService.awaitApproval(response);
      await activateAtClient(
        atsign: atsign,
        atClientPreference: atClientPreference,
        atKeys: response.atAuthKeys,
        enrollmentId: response.enrollmentId,
      );
      await _setStateOnStatus(EnrollmentStatus.approved);
    } catch (e, st) {
      App.log('Error awaiting enrollment approval: $e'.loggable);
      App.log(st.toString().loggable);
      await _setStateOnStatus(EnrollmentStatus.denied);
    }
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
      ).pop(NoPortsOnboardingResult.success(atsign: widget.atsign));
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

  Future<void> otpSubmit(String otp) async {
    setState(() {
      onboardingStatus = OnboardingStatus.validatingOtp;
      hasExpired = false;
    });

    // Device name cannot contain spaces or special characters
    final regExp = RegExp(r'[^a-zA-Z0-9]');
    final deviceName = (await getDeviceName()).replaceAll(regExp, '');
    App.log('Device Name: $deviceName'.loggable);

    final AtEnrollmentRequest enrollmentRequest = AtEnrollmentRequest(
      atSign: atsign,
      appName: Constants.namespace,
      deviceName: deviceName,
      otp: otp,
      namespaces: {Constants.namespace: 'rw', "sshnp": 'rw', 'sshrvd': 'rw'},
      rootDomain: AtRootDomain(
        atClientPreference.rootDomain,
        atClientPreference.rootPort,
      ),
    );

    App.log('About to enroll with $enrollmentRequest'.loggable);

    try {
      final enrollResponse = await enrollmentService.enroll(enrollmentRequest);
      App.log('Enroll response: $enrollResponse'.loggable);
      if (mounted) {
        setState(() {
          onboardingStatus = OnboardingStatus.pendingApproval;
        });
      }
      await _awaitApproval(enrollResponse);
      return;
    } on AtException catch (e, st) {
      App.log('AtException - Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);
      if (mounted) {
        Navigator.of(context).pop(NoPortsOnboardingResult.error(message: e.message));
      }
    } catch (e, st) {
      App.log('Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);

      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        // Doesn't seem like enroll throws an `AtException`.
        if (e.toString().contains('AT0022')) {
          App.log('Invalid OTP'.loggable);
          Navigator.of(
            context,
          ).pop(NoPortsOnboardingResult.error(message: strings.invalidOtp));
        } else {
          App.log('Unknown error during enrollment: $e'.loggable);
          Navigator.of(
            context,
          ).pop(NoPortsOnboardingResult.error(message: strings.unknownError));
        }
      }
    }

    if (mounted) {
      setState(() {
        onboardingStatus = OnboardingStatus.pendingApproval;
      });
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
              if (hasExpired) ...[
                gapH4,
                Text(
                  strings.requestExpired,
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
                            onboardingStatus: onboardingStatus,
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
                onboardingStatus: onboardingStatus,
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
                onboardingStatus: onboardingStatus,
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
