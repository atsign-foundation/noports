import 'package:at_client_flutter/at_client_flutter.dart'
    show AuthorisationListTile, ManageDeviceCard;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';
import 'package:npt_flutter/features/authorisation/models/authorisation_page_section.dart';

class AuthorisationSectionList extends StatelessWidget {
  const AuthorisationSectionList({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 340,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (controller.isManagerKey)
                const ManageDeviceCard()
              else
                const _NotAManagerKeyCard(),
              const SizedBox(height: 24),
              BlocBuilder<PendingRequestsCountCubit, Count>(
                builder: (BuildContext context, Count count) {
                  return AuthorisationListTile(
                    leading: AuthorisationPageSection.requests.icon,
                    title: AuthorisationPageSection.requests.title,
                    isSelected:
                        controller.section == AuthorisationPageSection.requests,
                    badgeCount: count.count,
                    onTap: () => controller.selectSection(
                      AuthorisationPageSection.requests,
                    ),
                  );
                },
              ),
              AuthorisationListTile(
                leading: AuthorisationPageSection.otp.icon,
                title: AuthorisationPageSection.otp.title,
                isSelected: controller.section == AuthorisationPageSection.otp,
                onTap: () =>
                    controller.selectSection(AuthorisationPageSection.otp),
                trailing: _OtpTrailing(controller: controller),
              ),
              AuthorisationListTile(
                leading: AuthorisationPageSection.setPin.icon,
                title: AuthorisationPageSection.setPin.title,
                isSelected:
                    controller.section == AuthorisationPageSection.setPin,
                onTap: () =>
                    controller.selectSection(AuthorisationPageSection.setPin),
              ),
              AuthorisationListTile(
                leading: AuthorisationPageSection.approvedEnrollments.icon,
                title: AuthorisationPageSection.approvedEnrollments.title,
                isSelected:
                    controller.section ==
                    AuthorisationPageSection.approvedEnrollments,
                onTap: () => controller.selectSection(
                  AuthorisationPageSection.approvedEnrollments,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpTrailing extends StatelessWidget {
  const _OtpTrailing({required this.controller});

  final AuthorisationHubController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.otpLoading) {
      return const SizedBox(
        height: 30,
        width: 30,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final String? otp = controller.otp?.value;
    if (otp == null) {
      return IconButton(
        tooltip: 'Generate OTP',
        icon: Icon(
          controller.otpError != null ? Icons.error_outline : Icons.refresh,
          color: controller.otpError != null
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        onPressed: () => controller.generateOtp(refresh: true),
      );
    }

    final bool isSelected =
        controller.section == AuthorisationPageSection.otp;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.surfaceContainerHigh
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              otp,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy OTP',
          icon: Icon(
            Icons.copy,
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: otp));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP copied to clipboard')),
            );
          },
        ),
      ],
    );
  }
}

class _NotAManagerKeyCard extends StatelessWidget {
  const _NotAManagerKeyCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Card(
            elevation: 0,
            color: Theme.of(
              context,
            ).colorScheme.secondary.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Not a Manager Device',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'The keys on this device are not authorised to manage enrollments. Approvals and revocations will be rejected by your atServer.',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
