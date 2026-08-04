import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/authorization/cubit/pending_requests_count_cubit.dart';
import 'package:npt_flutter/home_wrapper_widget.dart';
import 'package:npt_flutter/localization/app_localizations.dart';
import 'package:npt_flutter/routes.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:visibility_detector/visibility_detector.dart';

class AuthorizationAppBarButton extends StatefulWidget {
  const AuthorizationAppBarButton({super.key});

  @override
  AuthorizationAppBarButtonState createState() =>
      AuthorizationAppBarButtonState();
}

class AuthorizationAppBarButtonState extends State<AuthorizationAppBarButton> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return VisibilityDetector(
      key: const Key('authorization_app_bar_button'),
      onVisibilityChanged: (visibilityInfo) {
        // Need a way of getting the latest count
        // When a page is pushed on top of this it doesn't get rebuilt
        // so using this as a proxy
        if (visibilityInfo.visibleFraction > 0.9) {
          unawaited(
            context.read<PendingRequestsCountCubit>().getPendingRequests(),
          );
        }
      },
      child: StreamBuilder(
        // TODO(zambrella): Implement the stream and make sure to cache it in init state
        // stream: context.read<FlutterEnrollmentService>().enrollmentRequests(statusFilters: [EnrollmentStatus.pending]),
        stream: Stream.value(null),
        builder: (context, snapshot) {
          // TODO(zambrella): On new request, display a notification
          return BlocBuilder<PendingRequestsCountCubit, Count>(
            builder: (context, authorizationNotificationCount) {
              return IconButton(
                tooltip: strings.authorization,
                icon: Badge.count(
                  count: authorizationNotificationCount.count,
                  isLabelVisible: authorizationNotificationCount.count > 0,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  textColor: Theme.of(context).colorScheme.primary,
                  child: PhosphorIcon(PhosphorIcons.key()),
                ),
                onPressed: () {
                  wrapperNav.currentState!.pushNamed(HomeRoutes.authorization);
                },
              );
            },
          );
        },
      ),
    );
  }
}
