import 'package:at_client_flutter/at_client_flutter.dart'
    show AuthorisationSectionHeader, TipCard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/models/authorisation_page_section.dart';

class OtpSection extends StatelessWidget {
  const OtpSection({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  Widget build(BuildContext context) {
    final String? otp = controller.otp?.value;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthorisationSectionHeader(
            title: 'OTP',
            icon: Icons.numbers,
          ),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: <Widget>[
                  Text(
                    'Use this to enroll other apps and devices.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  if (controller.otpLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (controller.otpError != null)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        controller.otpError!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (otp != null)
                    Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        ...otp.split('').map((String character) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Container(
                              width: 50,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    character,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.headlineMedium,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      TextButton.icon(
                        onPressed: otp != null
                            ? () async {
                                await Clipboard.setData(
                                  ClipboardData(text: otp),
                                );
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('OTP copied to clipboard'),
                                  ),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy OTP'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: controller.otpLoading
                            ? null
                            : () async {
                                await controller.generateOtp(refresh: true);
                              },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh OTP'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          TipCard(
            tip:
                'Setting up multiple devices? Set up a PIN to avoid regenerating new OTPs',
            onTap: () {
              controller.selectSection(AuthorisationPageSection.setPin);
            },
          ),
        ],
      ),
    );
  }
}
