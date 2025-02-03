import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';
import 'package:npt_flutter/routes.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AuthorisationAppBarButton extends StatefulWidget {
  const AuthorisationAppBarButton({super.key});

  @override
  AuthorisationAppBarButtonState createState() => AuthorisationAppBarButtonState();
}

class AuthorisationAppBarButtonState extends State<AuthorisationAppBarButton> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return VisibilityDetector(
      key: const Key('authorisation_app_bar_button'),
      onVisibilityChanged: (visibilityInfo) {
        // Need a way of getting the latest count
        // When a page is pushed on top of this it doesn't get rebuilt
        // so using this as a proxy
        if (visibilityInfo.visibleFraction > 0.9) {
          unawaited(context.read<PendingRequestsCountCubit>().getPendingRequests());
        }
      },
      child: StreamBuilder(
        // TODO(zambrella): Implement the stream and make sure to cache it in init state
        // stream: context.read<AuthorisationService>().enrollmentRequests(statusFilters: [EnrollmentStatus.pending]),
        stream: Stream.value(null),
        builder: (context, snapshot) {
          // TODO(zambrella): On new request, display a notification
          return BlocBuilder<PendingRequestsCountCubit, Count>(
            builder: (context, authorisationNotificationCount) {
              return IconButton(
                tooltip: strings.authorisation,
                icon: Badge.count(
                  count: authorisationNotificationCount.count,
                  isLabelVisible: authorisationNotificationCount.count > 0,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  textColor: Theme.of(context).colorScheme.primary,
                  child: const Icon(Icons.key_outlined),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, Routes.authorisation);
                },
              );
            },
          );
        },
      ),
    );
  }
}
