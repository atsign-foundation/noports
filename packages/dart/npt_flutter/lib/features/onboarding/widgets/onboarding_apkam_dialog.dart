import 'dart:developer';
import 'dart:io';

import 'package:at_auth/at_auth.dart';
import 'package:at_client_flutter/at_client_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/onboarding/models/onboard_result.dart';
import 'package:npt_flutter/features/onboarding/widgets/enrollment_dialog.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/styles/sizes.dart';
import 'package:npt_flutter/util/constants.dart';
import 'package:pin_code_fields/pin_code_fields.dart'
    show
        MaterialPinField,
        MaterialPinTheme,
        MaterialPinShape,
        PinInputController;

import '../../../app.dart';

enum _ApkamDialogStatus {
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

  _ApkamDialogStatus _status = _ApkamDialogStatus.preparing;
  late final PinInputController _pinController;
  final _enrollmentService = FlutterEnrollmentService();
  final _keychainStorage = KeychainStorage();
  bool hasExpired = false;

  @override
  void initState() {
    super.initState();
    _pinController = PinInputController();
    _init();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<String> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return '${info.manufacturer} ${info.model}';
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return '${info.name} (${info.model})';
    } else if (Platform.isMacOS) {
      return (await deviceInfo.macOsInfo).computerName;
    } else if (Platform.isWindows) {
      return (await deviceInfo.windowsInfo).computerName;
    } else if (Platform.isLinux) {
      return (await deviceInfo.linuxInfo).name;
    }
    return 'Unknown Device';
  }

  Future<void> _init() async {
    final enrollmentData = await _keychainStorage.readEnrollmentData(atsign);

    if (enrollmentData == null) {
      setState(() {
        _status = _ApkamDialogStatus.otpRequired;
      });
      return;
    }

    final ageHours = Duration(
      microseconds:
          DateTime.now().toUtc().microsecondsSinceEpoch -
          enrollmentData.enrollmentSubmissionTimeEpoch,
    ).inHours;

    if (ageHours >= 48) {
      await _keychainStorage.deleteEnrollmentData(atsign);
      setState(() {
        hasExpired = true;
        _status = _ApkamDialogStatus.otpRequired;
      });
      return;
    }

    // Pending enrollment from a previous session — resume waiting
    setState(() {
      _status = _ApkamDialogStatus.pendingApproval;
    });
    final rootDomain = AtRootDomain(
      atClientPreference.rootDomain,
      atClientPreference.rootPort,
    );
    final pendingResponse = AtEnrollmentResponse(
      enrollmentData.enrollmentId,
      EnrollmentStatus.pending,
      atSign: atsign,
      rootDomain: rootDomain,
      atAuthKeys: enrollmentData.atAuthKeys,
    );
    _awaitApproval(pendingResponse);
  }

  void _awaitApproval(AtEnrollmentResponse response) {
    _enrollmentService
        .awaitApproval(response)
        .then((_) => _onApproved(response))
        .catchError((Object e) {
          final msg = e.toString();
          if (msg.contains('denied') || msg.contains('AT0025')) {
            _onDenied();
          } else {
            log('APKAM awaitApproval error: $e');
            if (mounted) {
              final strings = AppLocalizations.of(context)!;
              Navigator.of(context).pop(OnboardError(strings.unknownError));
            }
          }
        });
  }

  Future<void> _onApproved(AtEnrollmentResponse response) async {
    setState(() {
      _status = _ApkamDialogStatus.success;
    });
    // Persist the full decrypted keys and clean up pending enrollment marker
    await KeychainAtKeysIo().write(atsign, response.atAuthKeys!);
    await _keychainStorage.deleteEnrollmentData(atsign);
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      Navigator.of(context).pop(
        OnboardSuccess(atsign.toAtsign(), enrollmentId: response.enrollmentId),
      );
    }
  }

  Future<void> _onDenied() async {
    setState(() {
      _status = _ApkamDialogStatus.denied;
    });
    await _keychainStorage.deleteEnrollmentData(atsign);
    await Future.delayed(const Duration(milliseconds: 3000));
    if (mounted) {
      final strings = AppLocalizations.of(context)!;
      Navigator.of(context).pop(OnboardError(strings.enrollRequestDenied));
    }
  }

  Future<void> _otpSubmit(String otp) async {
    setState(() {
      _status = _ApkamDialogStatus.validatingOtp;
      hasExpired = false;
    });

    final regExp = RegExp(r'[^a-zA-Z0-9]');
    final deviceName = (await _getDeviceName()).replaceAll(regExp, '');
    App.log('Device Name: $deviceName'.loggable);

    final rootDomain = AtRootDomain(
      atClientPreference.rootDomain,
      atClientPreference.rootPort,
    );
    final enrollmentRequest = AtEnrollmentRequest(
      appName: Constants.namespace,
      deviceName: deviceName,
      atSign: atsign,
      otp: otp,
      namespaces: {Constants.namespace: 'rw', 'sshnp': 'rw', 'sshrvd': 'rw'},
      rootDomain: rootDomain,
    );

    App.log('About to enroll with $enrollmentRequest'.loggable);

    try {
      final response = await _enrollmentService.enroll(enrollmentRequest);
      App.log('Enroll response: $response'.loggable);
      setState(() {
        _status = _ApkamDialogStatus.pendingApproval;
      });
      _awaitApproval(response);
    } on AtException catch (e, st) {
      App.log('AtException - Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);
      if (mounted) {
        Navigator.of(context).pop(OnboardError(e.message));
      }
    } catch (e, st) {
      App.log('Error enrolling: $e'.loggable);
      App.log(st.toString().loggable);
      if (mounted) {
        final strings = AppLocalizations.of(context)!;
        if (e.toString().contains('AT0022')) {
          Navigator.of(context).pop(OnboardError(strings.invalidOtp));
        } else {
          Navigator.of(context).pop(OnboardError(strings.unknownError));
        }
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
        child: switch (_status) {
          _ApkamDialogStatus.preparing => const CircularProgressIndicator(
            key: Key('preparing'),
          ),
          _ApkamDialogStatus.otpRequired ||
          _ApkamDialogStatus.validatingOtp => Column(
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
                          MaterialPinField(
                            length: _kPinLength,
                            pinController: _pinController,
                            autoFocus: true,
                            textCapitalization: TextCapitalization.characters,
                            keyboardType: TextInputType.visiblePassword,
                            theme: const MaterialPinTheme(
                              shape: MaterialPinShape.outlined,
                              cellSize: Size(48, 52),
                            ),
                            onCompleted: (_) => _otpSubmit(_pinController.text),
                          ),
                          gapH8,
                          ListenableBuilder(
                            listenable: _pinController,
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
                                    _pinController.text.length == _kPinLength &&
                                        _status !=
                                            _ApkamDialogStatus.validatingOtp
                                    ? () async {
                                        await _otpSubmit(_pinController.text);
                                      }
                                    : null,
                                child:
                                    _status == _ApkamDialogStatus.validatingOtp
                                    ? const CircularProgressIndicator()
                                    : Text(strings.submitOtp),
                              );
                            },
                          ),
                          gapH8,
                          _PopButton(
                            canPop:
                                _status != _ApkamDialogStatus.pendingApproval,
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
          _ApkamDialogStatus.pendingApproval => Column(
            key: const Key('activating'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
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
          _ApkamDialogStatus.success => Column(
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
              _PopButton(canPop: true, title: strings.done),
            ],
          ),
          _ApkamDialogStatus.denied => Column(
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
              _PopButton(canPop: true, title: strings.done),
            ],
          ),
        },
      ),
    );
  }
}

class _PopButton extends StatelessWidget {
  const _PopButton({required this.canPop, required this.title});

  final bool canPop;
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
      onPressed: canPop ? () => Navigator.of(context).pop() : null,
      child: Text(title),
    );
  }
}
