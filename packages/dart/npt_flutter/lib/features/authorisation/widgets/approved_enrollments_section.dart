import 'dart:async';

import 'package:at_auth/at_auth.dart'
    show NamespacePermission, ServerEnrollmentRequest;
import 'package:at_client_flutter/at_client_flutter.dart'
    show
        AuthorisationFeedbackOverlay,
        AuthorisationSectionHeader,
        EnrollmentRequestCard,
        EnrollmentStatus;
import 'package:flutter/material.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';

class ApprovedEnrollmentsSection extends StatefulWidget {
  const ApprovedEnrollmentsSection({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  State<ApprovedEnrollmentsSection> createState() =>
      _ApprovedEnrollmentsSectionState();
}

class _ApprovedEnrollmentsSectionState
    extends State<ApprovedEnrollmentsSection> {
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  void _showRevokedOverlay(ServerEnrollmentRequest request) {
    _removeOverlay();
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext overlayContext) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 50, right: 20),
            child: Material(
              color: Colors.transparent,
              child: AuthorisationFeedbackOverlay(
                request: request,
                newStatus: EnrollmentStatus.revoked,
                onTap: _removeOverlay,
              ),
            ),
          ),
        );
      },
    );
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);
    _overlayTimer = Timer(const Duration(seconds: 3), _removeOverlay);
  }

  void _removeOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = null;
    _overlayEntry?.remove();
    _overlayEntry?.dispose();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthorisationHubController controller = widget.controller;
    final List<ServerEnrollmentRequest> requests = controller.approved
        .where(
          (ServerEnrollmentRequest request) =>
              !request.namespacePermissions.any(
                (NamespacePermission permission) =>
                    permission.namespace == '__manage',
              ),
        )
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: AuthorisationSectionHeader(
                  title: 'Approved Enrollments',
                  icon: Icons.done_all,
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: controller.approvedLoading
                    ? null
                    : () => controller.loadApprovedEnrollments(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (controller.approvedLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (controller.approvedError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                controller.approvedError!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          if (!controller.approvedLoading && requests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No approved enrollments'),
            ),
          if (!controller.approvedLoading)
            ...requests.map((ServerEnrollmentRequest request) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: EnrollmentRequestCard(
                  request: request,
                  onRevoke: () async {
                    final bool revoked = await controller.revoke(request);
                    if (revoked && mounted) {
                      _showRevokedOverlay(request);
                    }
                  },
                ),
              );
            }),
        ],
      ),
    );
  }
}
