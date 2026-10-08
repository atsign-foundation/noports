import 'package:at_client_flutter/at_client_flutter.dart'
    show AuthorisationSectionHeader;
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/widgets/spp_widget.dart';

class SetPinSection extends StatelessWidget {
  const SetPinSection({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const AuthorisationSectionHeader(
            title: 'Set pin',
            icon: Icons.dialpad,
          ),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Create a memorable PIN to use when onboarding your atSign in other apps and devices.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  if (controller.sppFetchError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        controller.sppFetchError!,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  SppWidget(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
