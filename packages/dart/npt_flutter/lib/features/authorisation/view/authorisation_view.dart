import 'dart:async';

import 'package:at_client_flutter/at_client_flutter.dart'
    show Atsign, AuthorisationSectionHeader, EnrollmentRequestList;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/models/authorisation_page_section.dart';
import 'package:npt_flutter/features/authorisation/widgets/approved_enrollments_section.dart';
import 'package:npt_flutter/features/authorisation/widgets/authorisation_section_list.dart';
import 'package:npt_flutter/features/authorisation/widgets/otp_section.dart';
import 'package:npt_flutter/features/authorisation/widgets/set_pin_section.dart';
import 'package:npt_flutter/features/onboarding/cubit/onboarding_cubit.dart';

class AuthorisationView extends StatelessWidget {
  const AuthorisationView({super.key});

  @override
  Widget build(BuildContext context) {
    final Atsign atsign = context.watch<OnboardingCubit>().getAtsign();
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: AuthorisationHub(key: ValueKey<String>('authorization_hub_$atsign')),
    );
  }
}

class AuthorisationHub extends StatefulWidget {
  const AuthorisationHub({super.key});

  @override
  State<AuthorisationHub> createState() => _AuthorisationHubState();
}

class _AuthorisationHubState extends State<AuthorisationHub> {
  late final AuthorisationHubController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AuthorisationHubController();
    unawaited(_controller.init());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListenableBuilder(
        listenable: _controller,
        builder: (BuildContext context, Widget? child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AuthorisationSectionList(controller: _controller),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: _buildSection(),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection() {
    switch (_controller.section) {
      case AuthorisationPageSection.requests:
        return const _RequestsSection();
      case AuthorisationPageSection.otp:
        return OtpSection(controller: _controller);
      case AuthorisationPageSection.setPin:
        return SetPinSection(controller: _controller);
      case AuthorisationPageSection.approvedEnrollments:
        return ApprovedEnrollmentsSection(controller: _controller);
    }
  }
}

class _RequestsSection extends StatelessWidget {
  const _RequestsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const AuthorisationSectionHeader(
          title: 'Requests',
          icon: Icons.question_mark_outlined,
        ),
        const Expanded(child: EnrollmentRequestList()),
      ],
    );
  }
}
