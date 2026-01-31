import 'package:at_client_mobile/at_client_mobile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:npt_mobile_flutter/features/onboarding/cubit/onboarding_cubit.dart';

// TODO: Authorization features are not available on mobile (server-only feature)
// Stubbed out until mobile support is added
class AuthorisationView extends StatelessWidget {
  const AuthorisationView({super.key});
  @override
  Widget build(BuildContext context) {
    final atSign = context.watch<OnboardingCubit>().getAtSign();
    // final authorisationService = context.watch<AuthorisationService>();

    return Padding(
      padding: const EdgeInsets.all(64.0),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                'Authorization Management',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This feature is not available on mobile devices.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'Use the desktop application to manage authorizations.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        // child: _EnrollmentRequestsView(
        //   // Ensure a unique key so that the widget is rebuilt when switching atsigns
        //   key: ValueKey('authorization_hub_$atSign'),
        //   authorisationService: authorisationService,
        //   atSign: atSign,
        // ),
      ),
    );
  }
}

/*
// Commented out - not available on mobile
class _EnrollmentRequestsView extends StatefulWidget {
  final AuthorisationService authorisationService;
  final String atSign;

  const _EnrollmentRequestsView({
    super.key,
    required this.authorisationService,
    required this.atSign,
  });

  @override
  State<_EnrollmentRequestsView> createState() => _EnrollmentRequestsViewState();
}

class _EnrollmentRequestsViewState extends State<_EnrollmentRequestsView> {
  List<EnrollmentRequest> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    // _loadRequests(); // Commented out - not available on mobile
  }

  /* Commented out - not available on mobile
  Future<void> _loadRequests() async {
    try {
      final requests = await widget.authorisationService.getEnrollmentRequests();
      setState(() {
        _requests = requests;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
    /* Commented out - not available on mobile
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_requests.isEmpty) {
      return const Center(
        child: Text('No enrollment requests'),
      );
    }

    return ListView.builder(
      itemCount: _requests.length,
      itemBuilder: (context, index) {
        final request = _requests[index];
        return ListTile(
          title: Text(request.appName ?? 'Unknown App'),
          subtitle: Text('Device: ${request.deviceName ?? "Unknown"}\n'
              'Status: ${request.enrollmentStatus}'),
          trailing: request.enrollmentStatus == EnrollmentStatus.pending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check, color: Colors.green),
                      onPressed: () async {
                        await widget.authorisationService.approve(request);
                        _loadRequests();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () async {
                        await widget.authorisationService.deny(request);
                        _loadRequests();
                      },
                    ),
                  ],
                )
              : null,
        );
      },
    );
    */
  }
}
*/
