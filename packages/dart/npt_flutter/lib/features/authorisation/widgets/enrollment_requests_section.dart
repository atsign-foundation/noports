import 'dart:async';

import 'package:at_auth/at_auth.dart' show ServerEnrollmentRequest;
import 'package:at_client_flutter/at_client_flutter.dart'
    show
        AuthorisationFeedbackOverlay,
        AuthorisationSectionHeader,
        EnrollmentRequestCard,
        EnrollmentStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_flutter/features/authorisation/controller/authorisation_hub_controller.dart';
import 'package:npt_flutter/features/authorisation/cubit/pending_requests_count_cubit.dart';

class EnrollmentRequestsSection extends StatefulWidget {
  const EnrollmentRequestsSection({required this.controller, super.key});

  final AuthorisationHubController controller;

  @override
  State<EnrollmentRequestsSection> createState() =>
      _EnrollmentRequestsSectionState();
}

class _EnrollmentRequestsSectionState extends State<EnrollmentRequestsSection> {
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  void _showFeedbackOverlay(
    ServerEnrollmentRequest request,
    EnrollmentStatus status,
  ) {
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
                newStatus: status,
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

  Future<void> _decide(
    ServerEnrollmentRequest request,
    Future<String?> Function(ServerEnrollmentRequest) decision,
    EnrollmentStatus outcome,
  ) async {
    final String? error = await decision(request);
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    _showFeedbackOverlay(request, outcome);
    unawaited(context.read<PendingRequestsCountCubit>().getPendingRequests());
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthorisationHubController controller = widget.controller;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const Expanded(
              child: AuthorisationSectionHeader(
                title: 'Requests',
                icon: Icons.question_mark_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              onPressed: controller.pendingLoading
                  ? null
                  : () => controller.loadPendingRequests(),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (controller.pendingError != null)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              controller.pendingError!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(child: _buildBody(controller)),
      ],
    );
  }

  Widget _buildBody(AuthorisationHubController controller) {
    if (controller.pendingLoading && controller.pending.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.pending.isEmpty) {
      return const Center(child: Text('No pending enrollment requests'));
    }

    return ListView.builder(
      itemCount: controller.pending.length,
      itemBuilder: (BuildContext context, int index) {
        final ServerEnrollmentRequest request = controller.pending[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: EnrollmentRequestCard(
            request: request,
            onApprove: () => _decide(
              request,
              controller.approveRequest,
              EnrollmentStatus.approved,
            ),
            onReject: () => _decide(
              request,
              controller.denyRequest,
              EnrollmentStatus.denied,
            ),
          ),
        );
      },
    );
  }
}
